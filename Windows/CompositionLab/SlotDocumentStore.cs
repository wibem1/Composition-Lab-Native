using System.Collections;
using System.Text.Json.Nodes;

namespace CompositionLab;

/// <summary>
/// Single owner of workspace slot references. UI components receive data via
/// bounded indices and explicit operations, not a mutable array reference.
/// Music score objects remain mutable for compatibility with existing editors;
/// deep immutability is a subsequent migration step.
/// </summary>
internal sealed class SlotDocumentStore : IReadOnlyList<JsonObject?>
{
    readonly JsonObject?[] slots;
    internal SlotDocumentStore(int capacity)
    {
        if (capacity < 1) throw new ArgumentOutOfRangeException(nameof(capacity));
        slots = new JsonObject?[capacity];
    }
    internal int Length => slots.Length;
    public int Count => slots.Length;
    public JsonObject? this[int index]
    {
        get => slots[index];
        set => slots[index] = value;
    }
    internal int FirstFreeIndex() => Array.FindIndex(slots, piece => piece == null);
    internal int IndexOfReference(JsonObject document) =>
        Array.FindIndex(slots, piece => ReferenceEquals(piece, document));

    /// <summary>Commit an already validated workspace in one synchronous operation.</summary>
    internal void ReplaceAll(IReadOnlyList<JsonObject?> next)
    {
        ArgumentNullException.ThrowIfNull(next);
        if (next.Count != slots.Length) throw new ArgumentException("Slot count mismatch.", nameof(next));
        var incoming = next.ToArray();
        Array.Copy(incoming, slots, slots.Length);
    }
    public IEnumerator<JsonObject?> GetEnumerator() => ((IEnumerable<JsonObject?>)slots).GetEnumerator();
    IEnumerator IEnumerable.GetEnumerator() => GetEnumerator();

    internal static void SelfTest()
    {
        var store = new SlotDocumentStore(3);
        if (store.FirstFreeIndex() != 0 || store.Count != 3)
            throw new Exception("SlotDocumentStore: initial state incorrect.");
        var original = new JsonObject { ["title"] = "Original" };
        store[0] = original;
        if (store.FirstFreeIndex() != 1 || store.IndexOfReference(original) != 0)
            throw new Exception("SlotDocumentStore: slot ownership incorrect.");
        bool rejected = false;
        try { store.ReplaceAll(new JsonObject?[2]); }
        catch (ArgumentException) { rejected = true; }
        if (!rejected || !ReferenceEquals(store[0], original))
            throw new Exception("SlotDocumentStore: rejected import overwrote existing slot.");
        store.ReplaceAll(new JsonObject?[] { null, original, null });
        if (store[0] != null || !ReferenceEquals(store[1], original))
            throw new Exception("SlotDocumentStore: complete replacement incorrect.");
    }
}
