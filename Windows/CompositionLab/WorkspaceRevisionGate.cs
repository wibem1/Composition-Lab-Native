namespace CompositionLab;

/// <summary>
/// Monotonic token gate for asynchronous workspace operations.
/// Does not own UI controls, documents, or transport processes.
/// </summary>
internal sealed class WorkspaceRevisionGate
{
    int generation;
    internal int Current => generation;
    internal int Begin() => checked(++generation);
    internal bool IsCurrent(int expected) => generation == expected;

    internal static void SelfTest()
    {
        var gate = new WorkspaceRevisionGate();
        int first = gate.Begin();
        if (!gate.IsCurrent(first)) throw new Exception("Revision gate: current request rejected.");
        int second = gate.Begin();
        if (gate.IsCurrent(first) || !gate.IsCurrent(second))
            throw new Exception("Revision gate: stale request accepted.");
    }
}
