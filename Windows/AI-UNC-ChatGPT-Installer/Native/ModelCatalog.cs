using AIUNCChatGPTInstaller.Models;

namespace AIUNCChatGPTInstaller;

internal static class ModelCatalog
{
    public const string DefaultModel = "gpt-5.6-sol";

    public static IReadOnlyList<ModelOption> Options { get; } =
    [
        new("gpt-5.6-sol", "gpt-5.6-sol", "Recommended default and latest frontier model for complex coding and long-running work.", ["low", "medium", "high", "xhigh", "ultra"], ["low", "medium", "high", "xhigh", "max", "ultra"], "medium"),
        new("gpt-5.6-terra", "gpt-5.6-terra", "Balanced model for everyday coding, debugging, and general work.", ["low", "medium", "high", "xhigh", "ultra"], ["low", "medium", "high", "xhigh", "max", "ultra"], "medium"),
        new("gpt-5.6-luna", "gpt-5.6-luna", "Fast, lightweight model for shorter coding tasks and quick edits.", ["low", "medium", "high", "xhigh"], ["low", "medium", "high", "xhigh", "max"], "medium"),
        new("gpt-5.5", "gpt-5.5", "Frontier model for complex coding, research, and real-world work.", ["low", "medium", "high", "xhigh"], ["low", "medium", "high", "xhigh"], "medium"),
        new("gpt-5.4", "gpt-5.4", "Strong model for everyday coding and debugging.", ["low", "medium", "high", "xhigh"], ["low", "medium", "high", "xhigh"], "medium"),
        new("gpt-5.4-mini", "gpt-5.4-mini", "Fast, lightweight model for straightforward coding tasks.", ["low", "medium", "high", "xhigh"], ["low", "medium", "high", "xhigh"], "medium"),
        new("gpt-5.4-nano", "gpt-5.4-nano", "Small approved model for simple tasks and compatibility.", [], [], null),
        new("gpt-5.3-codex", "gpt-5.3-codex", "Coding-focused model for software development workflows.", ["low", "medium", "high", "xhigh"], ["low", "medium", "high", "xhigh"], "medium"),
        new("gpt-5.2", "gpt-5.2", "Model for professional work and long-running agent tasks.", ["low", "medium", "high", "xhigh"], ["low", "medium", "high", "xhigh"], "medium"),
        new("gpt-5.1", "gpt-5.1", "Earlier general-purpose GPT-5 model for existing workflows.", [], [], null),
        new("gpt-5", "gpt-5", "Earlier GPT-5 model for general work and compatibility.", [], [], null),
        new("gpt-5-mini", "gpt-5-mini", "Earlier lightweight GPT-5 model for simple, quick tasks.", [], [], null),
        new("gpt-5-nano", "gpt-5-nano", "Small earlier GPT-5 model for basic, low-complexity tasks.", [], [], null),
        new("gpt-4.1", "gpt-4.1", "Earlier general-purpose model for coding and instruction-following tasks.", [], [], null),
        new("gpt-4.1-mini", "gpt-4.1-mini", "Earlier lightweight general-purpose model for shorter tasks.", [], [], null),
        new("gpt-4.1-nano", "gpt-4.1-nano", "Small earlier model for basic, low-complexity tasks.", [], [], null),
        new("gpt-4o", "gpt-4o", "Earlier general-purpose model for text, coding, and multimodal workflows.", [], [], null),
        new("gpt-4o-mini", "gpt-4o-mini", "Earlier lightweight model for shorter text and multimodal tasks.", [], [], null),
        new("o1", "o1", "Earlier deep-reasoning model for complex problems; uses model-default effort.", [], [], null),
        new("o1-preview", "o1-preview", "Preview-era deep-reasoning model for compatibility with existing workflows.", [], [], null),
        new("o1-mini", "o1-mini", "Earlier compact reasoning model for focused problems; uses model-default effort.", [], [], null),
        new("o3-mini", "o3-mini", "Earlier compact reasoning model for coding, math, and logic tasks.", [], [], null),
        new("chat", "chat (gpt-4.1-mini)", "Compatibility alias for the gpt-4.1-mini chat deployment.", [], [], null)
    ];

    public static ModelOption Default =>
        Options.First(option => option.Deployment == DefaultModel);

    public static string ReasoningDescription(string? effort) => effort switch
    {
        "low" => "Faster responses with lighter reasoning for straightforward tasks.",
        "medium" => "Recommended balance of speed and reasoning depth for most work.",
        "high" => "More careful reasoning for complex code changes and troubleshooting.",
        "xhigh" => "Deep reasoning for difficult tasks; responses may take longer.",
        "max" => "Maximum supported reasoning for the hardest tasks; expect the longest waits.",
        "ultra" => "Maximum reasoning with automatic task delegation for large, multi-step work.",
        _ => "Uses the model-default reasoning setting."
    };
}
