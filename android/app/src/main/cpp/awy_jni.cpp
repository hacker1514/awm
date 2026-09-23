#include <jni.h>
#include <string>
#include <vector>
#include <atomic>
#include <mutex>
#include <algorithm>
#include <exception>
#include <android/log.h>

#include "llama.h"

#define LOG_TAG "AWM_LlamaJNI"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

static llama_model* g_model = nullptr;
static llama_context* g_ctx = nullptr;
static const llama_vocab* g_vocab = nullptr;
static llama_sampler* g_smpl = nullptr;
static std::mutex g_llama_mutex;
static std::atomic<bool> g_stop_requested(false);
static std::once_flag g_backend_once;

static void init_llama_backend_once() {
    llama_backend_init();
    LOGI("llama_backend_init completed successfully");
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_awm_aiwithme_LlamaBridge_nativeInitModel(
        JNIEnv* env,
        jobject thiz,
        jstring modelPath,
        jint nCtx,
        jint nThreads) {
    std::lock_guard<std::mutex> lock(g_llama_mutex);

    try {
        std::call_once(g_backend_once, init_llama_backend_once);

        if (g_smpl != nullptr) {
            llama_sampler_free(g_smpl);
            g_smpl = nullptr;
        }
        if (g_ctx != nullptr) {
            llama_free(g_ctx);
            g_ctx = nullptr;
        }
        if (g_model != nullptr) {
            llama_model_free(g_model);
            g_model = nullptr;
        }

        const char* path_chars = env->GetStringUTFChars(modelPath, nullptr);
        if (!path_chars) {
            LOGE("Failed to get model path string");
            return JNI_FALSE;
        }

        LOGI("Loading GGUF model from file: %s", path_chars);
        llama_model_params mparams = llama_model_default_params();
        mparams.n_gpu_layers = 0; // CPU inference for compatibility with low-end devices like Vivo Y12

        g_model = llama_model_load_from_file(path_chars, mparams);
        env->ReleaseStringUTFChars(modelPath, path_chars);

        if (!g_model) {
            LOGE("Failed to load GGUF model file");
            return JNI_FALSE;
        }

        g_vocab = llama_model_get_vocab(g_model);
        if (!g_vocab) {
            LOGE("Failed to get model vocabulary");
            llama_model_free(g_model);
            g_model = nullptr;
            return JNI_FALSE;
        }

        llama_context_params cparams = llama_context_default_params();
        cparams.n_ctx = 1024; // 1024 context window for low RAM mobile devices
        cparams.n_batch = 256;
        cparams.n_ubatch = 256;
        cparams.n_threads = 2; // Conservative thread count for mobile CPUs
        cparams.n_threads_batch = 2;
        cparams.no_perf = true;

        g_ctx = llama_init_from_model(g_model, cparams);
        if (!g_ctx) {
            LOGE("Failed to create llama context");
            llama_model_free(g_model);
            g_model = nullptr;
            return JNI_FALSE;
        }

        // Initialize reusable sampler chain once
        auto sparams = llama_sampler_chain_default_params();
        g_smpl = llama_sampler_chain_init(sparams);
        llama_sampler_chain_add(g_smpl, llama_sampler_init_top_k(40));
        llama_sampler_chain_add(g_smpl, llama_sampler_init_top_p(0.9f, 1));
        llama_sampler_chain_add(g_smpl, llama_sampler_init_temp(0.7f));
        llama_sampler_chain_add(g_smpl, llama_sampler_init_dist(LLAMA_DEFAULT_SEED));

        LOGI("llama model successfully initialized with n_ctx=1024");
        return JNI_TRUE;
    } catch (const std::exception& e) {
        LOGE("Exception in nativeInitModel: %s", e.what());
        return JNI_FALSE;
    } catch (...) {
        LOGE("Unknown exception in nativeInitModel");
        return JNI_FALSE;
    }
}

extern "C" JNIEXPORT void JNICALL
Java_com_awm_aiwithme_LlamaBridge_nativeGenerate(
        JNIEnv* env,
        jobject thiz,
        jstring promptStr,
        jobject callback) {
    std::lock_guard<std::mutex> lock(g_llama_mutex);
    g_stop_requested.store(false);

    jclass interfaceClass = env->FindClass("com/awm/aiwithme/LlamaBridge$LlamaCallback");
    jmethodID onBytesMethod = nullptr;
    jmethodID onCompleteMethod = nullptr;

    if (interfaceClass) {
        onBytesMethod = env->GetMethodID(interfaceClass, "onTokenBytes", "([B)V");
        onCompleteMethod = env->GetMethodID(interfaceClass, "onGenerationComplete", "()V");
    }

    if (env->ExceptionCheck()) {
        env->ExceptionClear();
    }

    try {
        if (!g_model || !g_ctx || !g_vocab || !g_smpl) {
            LOGE("Cannot generate: Llama model/context/sampler not initialized");
            if (callback && onCompleteMethod) {
                env->CallVoidMethod(callback, onCompleteMethod);
                if (env->ExceptionCheck()) env->ExceptionClear();
            }
            return;
        }

        const char* prompt_chars = env->GetStringUTFChars(promptStr, nullptr);
        if (!prompt_chars) {
            LOGE("Failed to get prompt string");
            if (callback && onCompleteMethod) {
                env->CallVoidMethod(callback, onCompleteMethod);
                if (env->ExceptionCheck()) env->ExceptionClear();
            }
            return;
        }

        std::string prompt(prompt_chars);
        env->ReleaseStringUTFChars(promptStr, prompt_chars);

        // Find token length for prompt using llama.cpp standard 2-pass tokenization
        int n_prompt = -llama_tokenize(g_vocab, prompt.c_str(), (int32_t)prompt.length(), NULL, 0, true, true);
        if (n_prompt <= 0) {
            LOGE("Tokenization failed for prompt");
            if (callback && onCompleteMethod) {
                env->CallVoidMethod(callback, onCompleteMethod);
                if (env->ExceptionCheck()) env->ExceptionClear();
            }
            return;
        }

        std::vector<llama_token> prompt_tokens(n_prompt);
        if (llama_tokenize(g_vocab, prompt.c_str(), (int32_t)prompt.length(), prompt_tokens.data(), prompt_tokens.size(), true, true) < 0) {
            LOGE("Failed to tokenize prompt");
            if (callback && onCompleteMethod) {
                env->CallVoidMethod(callback, onCompleteMethod);
                if (env->ExceptionCheck()) env->ExceptionClear();
            }
            return;
        }

        // Reset sampler and context KV memory state before new turn
        llama_sampler_reset(g_smpl);
        llama_memory_t mem = llama_get_memory(g_ctx);
        if (mem) {
            llama_memory_seq_rm(mem, -1, -1, -1);
        }

        // Evaluate prompt batch using official llama_batch_get_one
        llama_batch batch = llama_batch_get_one(prompt_tokens.data(), prompt_tokens.size());
        if (llama_decode(g_ctx, batch) != 0) {
            LOGE("llama_decode failed during prompt processing");
            if (callback && onCompleteMethod) {
                env->CallVoidMethod(callback, onCompleteMethod);
                if (env->ExceptionCheck()) env->ExceptionClear();
            }
            return;
        }

        int n_predict = 384;
        int n_cur = prompt_tokens.size();

        while (n_predict > 0 && !g_stop_requested.load()) {
            llama_token new_token_id = llama_sampler_sample(g_smpl, g_ctx, -1);
            if (llama_vocab_is_eog(g_vocab, new_token_id)) {
                LOGI("End of generation token reached");
                break;
            }

            char piece_buf[256];
            int n_piece = llama_token_to_piece(g_vocab, new_token_id, piece_buf, sizeof(piece_buf), 0, true);
            if (n_piece > 0) {
                jbyteArray byteArray = env->NewByteArray(n_piece);
                if (byteArray) {
                    env->SetByteArrayRegion(byteArray, 0, n_piece, (jbyte*)piece_buf);
                    if (callback && onBytesMethod) {
                        env->CallVoidMethod(callback, onBytesMethod, byteArray);
                        if (env->ExceptionCheck()) env->ExceptionClear();
                    }
                    env->DeleteLocalRef(byteArray);
                }
            }

            // Prepare next single token batch
            batch = llama_batch_get_one(&new_token_id, 1);
            if (llama_decode(g_ctx, batch) != 0) {
                LOGE("llama_decode failed during single token generation");
                break;
            }

            n_cur++;
            n_predict--;
        }

    } catch (const std::exception& e) {
        LOGE("Exception in nativeGenerate: %s", e.what());
    } catch (...) {
        LOGE("Unknown exception in nativeGenerate");
    }

    if (callback && onCompleteMethod) {
        env->CallVoidMethod(callback, onCompleteMethod);
        if (env->ExceptionCheck()) env->ExceptionClear();
    }

    if (interfaceClass) {
        env->DeleteLocalRef(interfaceClass);
    }
}

extern "C" JNIEXPORT void JNICALL
Java_com_awm_aiwithme_LlamaBridge_nativeStopGeneration(
        JNIEnv* env,
        jobject thiz) {
    LOGI("Stop generation requested");
    g_stop_requested.store(true);
}

extern "C" JNIEXPORT void JNICALL
Java_com_awm_aiwithme_LlamaBridge_nativeFreeModel(
        JNIEnv* env,
        jobject thiz) {
    std::lock_guard<std::mutex> lock(g_llama_mutex);
    LOGI("Freeing llama model resources");
    try {
        if (g_smpl) {
            llama_sampler_free(g_smpl);
            g_smpl = nullptr;
        }
        if (g_ctx) {
            llama_free(g_ctx);
            g_ctx = nullptr;
        }
        if (g_model) {
            llama_model_free(g_model);
            g_model = nullptr;
        }
        g_vocab = nullptr;
    } catch (...) {
        LOGE("Exception while freeing llama model");
    }
}
