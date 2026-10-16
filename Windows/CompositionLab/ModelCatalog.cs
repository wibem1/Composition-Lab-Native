using System.Net.Http;
using System.Net.Http.Headers;
using System.Text.Json.Nodes;

namespace CompositionLab;

internal sealed record CatalogModel(string Id, string Name, string Details);
internal sealed record ModelSnapshot(DateTimeOffset LoadedAt, List<CatalogModel> Models);

internal sealed class ModelCatalogClient(HttpClient client)
{
    public async Task<List<CatalogModel>> ListAsync(string provider, string key, CancellationToken cancellation = default)
    {
        if (string.IsNullOrWhiteSpace(key)) throw new InvalidOperationException("Bitte zuerst den API-Schlüssel dieses Providers eintragen.");
        var found = new Dictionary<string, CatalogModel>(StringComparer.Ordinal);
        var cursors = new HashSet<string>(StringComparer.Ordinal);
        string cursor = "";
        for (int page = 0; page < 500; page++)
        {
            string url = provider switch
            {
                "openai" => "https://api.openai.com/v1/models" + (cursor.Length == 0 ? "" : "?after=" + Uri.EscapeDataString(cursor)),
                "anthropic" => "https://api.anthropic.com/v1/models?limit=1000" + (cursor.Length == 0 ? "" : "&after_id=" + Uri.EscapeDataString(cursor)),
                "gemini" => "https://generativelanguage.googleapis.com/v1beta/models?pageSize=1000" + (cursor.Length == 0 ? "" : "&pageToken=" + Uri.EscapeDataString(cursor)),
                _ => throw new InvalidOperationException("Unbekannter Provider.")
            };
            using var request = new HttpRequestMessage(HttpMethod.Get, url);
            if (provider == "openai") request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", key.Trim());
            else if (provider == "anthropic") { request.Headers.Add("x-api-key", key.Trim()); request.Headers.Add("anthropic-version", "2023-06-01"); }
            else request.Headers.Add("x-goog-api-key", key.Trim());
            using var response = await client.SendAsync(request, cancellation);
            if (!response.IsSuccessStatusCode)
                throw new InvalidOperationException($"Modellliste konnte nicht geladen werden (HTTP {(int)response.StatusCode}). API-Schlüssel und Provider-Zugriff prüfen. Die bisherige Liste bleibt erhalten.");
            var root = JsonNode.Parse(await response.Content.ReadAsStringAsync(cancellation))?.AsObject()
                ?? throw new InvalidDataException("Leere Modellantwort.");
            var items = root[provider == "gemini" ? "models" : "data"] as JsonArray
                ?? throw new InvalidDataException("Die Provider-Antwort enthält keine Modellliste.");
            foreach (var item in items.OfType<JsonObject>())
            {
                string id = item[provider == "gemini" ? "name" : "id"]?.GetValue<string>() ?? "";
                if (provider == "gemini" && id.StartsWith("models/", StringComparison.Ordinal)) id = id[7..];
                if (id.Length == 0) throw new InvalidDataException("Ein Modell enthält keine Kennung; die Liste wurde nicht übernommen.");
                string name = item[provider == "gemini" ? "displayName" : "display_name"]?.GetValue<string>() ?? id;
                var detail = new List<string>();
                if (item["description"] is JsonValue description) detail.Add(description.GetValue<string>());
                if (item["supportedGenerationMethods"] is JsonArray methods) detail.Add("Funktionen: " + string.Join(", ", methods.Select(x => x?.GetValue<string>())));
                if (item["owned_by"] is JsonValue owner) detail.Add("Anbieter: " + owner.GetValue<string>());
                foreach (string field in new[] { "inputTokenLimit", "outputTokenLimit", "max_input_tokens", "max_tokens", "lifecycle" })
                    if (item[field] != null) detail.Add(field + ": " + item[field]);
                if (item["capabilities"] is JsonObject capabilities)
                    detail.Add("Funktionen: " + string.Join(", ", capabilities.Where(p => p.Value is JsonObject capability && capability["supported"]?.GetValue<bool>() == true).Select(p => p.Key)));
                found[id] = new CatalogModel(id, name, string.Join("\r\n", detail));
            }
            string next = provider == "gemini" ? root["nextPageToken"]?.GetValue<string>() ?? "" :
                root["has_more"]?.GetValue<bool>() == true ? root["last_id"]?.GetValue<string>() ?? items.LastOrDefault()?["id"]?.GetValue<string>() ?? "" : "";
            if (provider != "gemini" && root["has_more"]?.GetValue<bool>() == true && next.Length == 0)
                throw new InvalidDataException("Unvollständige Modellliste: nächste Seite fehlt.");
            if (next.Length == 0)
            {
                if (found.Count == 0) throw new InvalidDataException("Der Provider hat keine verfügbaren Modelle gemeldet. Die bisherige Liste bleibt erhalten.");
                return found.Values.OrderBy(m => m.Name, StringComparer.OrdinalIgnoreCase).ThenBy(m => m.Id, StringComparer.Ordinal).ToList();
            }
            if (!cursors.Add(next)) throw new InvalidDataException("Wiederholte Modellseite; die unvollständige Liste wurde nicht übernommen.");
            cursor = next;
        }
        throw new InvalidDataException("Zu viele Modellseiten; die unvollständige Liste wurde nicht übernommen.");
    }
}
