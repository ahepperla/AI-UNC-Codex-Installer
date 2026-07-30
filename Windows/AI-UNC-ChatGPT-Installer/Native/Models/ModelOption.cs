namespace AIUNCChatGPTInstaller.Models;

internal sealed record ModelOption(
    string Deployment,
    string Label,
    string Description,
    string[] Reasoning,
    string[] CatalogReasoning,
    string? DefaultReasoning)
{
    public override string ToString() => Label;
}
