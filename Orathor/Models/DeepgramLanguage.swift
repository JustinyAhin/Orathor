struct DeepgramLanguage {
    let code: String
    let label: String

    static let allOptions: [DeepgramLanguage] = [
        DeepgramLanguage(code: "multi", label: "Auto-detect"),
        DeepgramLanguage(code: "en", label: "English"),
        DeepgramLanguage(code: "fr", label: "French"),
        DeepgramLanguage(code: "de", label: "German"),
        DeepgramLanguage(code: "es", label: "Spanish"),
        DeepgramLanguage(code: "pt", label: "Portuguese"),
        DeepgramLanguage(code: "it", label: "Italian"),
        DeepgramLanguage(code: "nl", label: "Dutch"),
        DeepgramLanguage(code: "ja", label: "Japanese"),
        DeepgramLanguage(code: "ko", label: "Korean"),
        DeepgramLanguage(code: "zh", label: "Chinese"),
        DeepgramLanguage(code: "hi", label: "Hindi"),
        DeepgramLanguage(code: "ar", label: "Arabic"),
        DeepgramLanguage(code: "ru", label: "Russian"),
        DeepgramLanguage(code: "sv", label: "Swedish"),
        DeepgramLanguage(code: "da", label: "Danish"),
        DeepgramLanguage(code: "no", label: "Norwegian"),
        DeepgramLanguage(code: "pl", label: "Polish"),
        DeepgramLanguage(code: "tr", label: "Turkish"),
        DeepgramLanguage(code: "uk", label: "Ukrainian"),
    ]
}
