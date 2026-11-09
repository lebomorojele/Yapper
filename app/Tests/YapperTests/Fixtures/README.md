`speech.wav` is the streaming ASR test recording from soniqo/speech-swift,
revision 03920e17671fc79d59da1573923958304e233c42, distributed under its Apache 2.0 license and resampled from 24 kHz to 16 kHz mono PCM.
Source: https://github.com/soniqo/speech-swift/blob/03920e17671fc79d59da1573923958304e233c42/Tests/ParakeetStreamingASRTests/Resources/test_audio.wav

The recording includes the phrases "guarantee" and "shipped tomorrow".
Run the real Yapper streaming transcriber against it on macOS:

    YAPPER_RUN_STT_INTEGRATION=1 swift test --package-path app --filter RealTranscriptionTests

This downloads the same Core ML model as the app's first launch. Other unit tests
run without downloading model weights.
