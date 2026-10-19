using System.Net.Http;
using System.Text.Json.Nodes;

namespace CompositionLab;

internal sealed record CatalogModel(string Id, string Name, string Details);
internal sealed record ModelSnapshot(DateTimeOffset LoadedAt, List<CatalogModel> Models);

// HTTP adapter only. The shared Swift catalog owns endpoints, metadata,
// pagination, deduplication and validation for both native interfaces.
internal sealed class ModelCatalogClient(HttpClient client)
{
    public async Task<List<CatalogModel>> ListAsync(string provider, string key, CancellationToken cancellation = default)
    {
        if (string.IsNullOrWhiteSpace(key)) throw new InvalidOperationException("Bitte zuerst den API-Schlüssel dieses Providers eintragen.");
        var core = new CoreClient();
        async Task<JsonObject> Step(JsonObject? state, JsonNode? page)
        {
            var input = new JsonObject { ["operation"] = "model-catalog-step", ["provider"] = provider };
            if (state != null) input["state"] = state.DeepClone();
            if (page != null) input["page"] = page.DeepClone();
            try { return (await core.RunAsync(input, cancellation))["catalog"]!.AsObject(); }
            catch (CoreRequestException e) { throw new InvalidDataException(e.Message, e); }
        }
        var catalog = await Step(null, null);
        while (catalog["state"]!["complete"]?.GetValue<bool>() != true)
        {
            var plan = catalog["request"]!;
            using var request = new HttpRequestMessage(HttpMethod.Get, plan["url"]!.GetValue<string>());
            request.Headers.Add(plan["keyHeader"]!.GetValue<string>(), plan["keyPrefix"]!.GetValue<string>() + key.Trim());
            foreach (var header in plan["headers"]!.AsObject()) request.Headers.Add(header.Key, header.Value!.GetValue<string>());
            using var response = await client.SendAsync(request, cancellation);
            if (!response.IsSuccessStatusCode)
                throw new InvalidOperationException($"Modellliste konnte nicht geladen werden (HTTP {(int)response.StatusCode}). API-Schlüssel und Provider-Zugriff prüfen. Die bisherige Liste bleibt erhalten.");
            var page = JsonNode.Parse(await response.Content.ReadAsStringAsync(cancellation))
                ?? throw new InvalidDataException("Leere Modellantwort.");
            catalog = await Step(catalog["state"]!.AsObject(), page);
        }
        return catalog["state"]!["models"]!.AsArray().Select(item => new CatalogModel(
            item!["id"]!.GetValue<string>(), item["name"]!.GetValue<string>(), item["details"]!.GetValue<string>())).ToList();
    }
}
