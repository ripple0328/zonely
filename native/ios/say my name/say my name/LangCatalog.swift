enum LangCatalog {
    static let allCodes: [String] = [
        "en-US","zh-CN","es-ES","hi-IN","ar-SA","bn-IN","fr-FR","pt-BR","ja-JP","de-DE"
    ]
    static func displayName(_ code: String) -> String {
        [
            "en-US":"English","zh-CN":"中文","ja-JP":"日本語","es-ES":"Español","fr-FR":"Français","de-DE":"Deutsch","pt-BR":"Português","hi-IN":"हिन्दी","ar-SA":"العربية","bn-IN":"বাংলা",
        ][code] ?? code
    }
}


