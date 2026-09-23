package com.awm.aiwithme

object LlamaBridge {
    interface LlamaCallback {
        fun onTokenBytes(bytes: ByteArray)
        fun onGenerationComplete()
    }

    init {
        try {
            System.loadLibrary("awy_llama")
        } catch (e: UnsatisfiedLinkError) {
            e.printStackTrace()
        }
    }

    external fun nativeInitModel(modelPath: String, nCtx: Int, nThreads: Int): Boolean
    external fun nativeGenerate(prompt: String, callback: LlamaCallback)
    external fun nativeStopGeneration()
    external fun nativeFreeModel()
}
