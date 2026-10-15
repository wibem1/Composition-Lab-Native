using System.Net;
using System.Net.Http;
using System.Text;
using System.Text.Json;

namespace CompositionLab;

internal static class ModelCatalogTests
{
    sealed class Stub(Func<HttpRequestMessage, int, HttpResponseMessage> response) : HttpMessageHandler
    {
        int count;
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        { cancellationToken.ThrowIfCancellationRequested(); return Task.FromResult(response(request, count++)); }
    }
    static HttpResponseMessage Json(string text) => new(HttpStatusCode.OK) { Content = new StringContent(text, Encoding.UTF8, "application/json") };
    public static async Task RunAsync()
    {
        const string key = "catalog-test-key-not-real";
        using (var http = new HttpClient(new Stub((request, _) =>
        {
            if (request.RequestUri!.Host != "api.openai.com" || request.Headers.Authorization?.ToString() != "Bearer " + key) throw new Exception("OpenAI-Modellauthentifizierung fehlt.");
            return Json(JsonSerializer.Serialize(new { data = Enumerable.Range(0, 235).Select(i => new { id = "future-model-" + i, owned_by = "provider" }).Append(new { id = "text-embedding-test", owned_by = "provider" }) }));
        })))
        {
            var result = await new ModelCatalogClient(http).ListAsync("openai", key);
            if (result.Count != 236 || !result.Any(m => m.Id == "text-embedding-test")) throw new Exception("OpenAI-Modellliste wird gekürzt oder gefiltert.");
        }
        using (var http = new HttpClient(new Stub((request, page) =>
        {
            if (!request.Headers.Contains("x-api-key") || !request.Headers.Contains("anthropic-version")) throw new Exception("Anthropic-Header fehlen.");
            if (page == 0) return Json("""{"data":[{"id":"claude-future-a","display_name":"Zukunft A"}],"has_more":true,"last_id":"a/b +"}""");
            if (!request.RequestUri!.Query.Contains("after_id=a%2Fb%20%2B", StringComparison.Ordinal)) throw new Exception("Anthropic-Seitencursor falsch übertragen.");
            return Json("""{"data":[{"id":"claude-future-b","display_name":"Zukunft B"},{"id":"claude-future-a","display_name":"Zukunft A"}],"has_more":false}""");
        })))
            if ((await new ModelCatalogClient(http).ListAsync("anthropic", key)).Count != 2) throw new Exception("Anthropic-Modellseiten fehlen oder enthalten Duplikate.");
        using (var http = new HttpClient(new Stub((request, page) =>
        {
            if (!request.Headers.Contains("x-goog-api-key") || request.RequestUri!.Query.Contains(key)) throw new Exception("Gemini-Schlüssel wird nicht ausschließlich im Header übertragen.");
            if (page == 0) return Json("""{"models":[{"name":"models/gemini-next","displayName":"Gemini Next","supportedGenerationMethods":["generateContent"]}],"nextPageToken":"token +/"}""");
            if (!request.RequestUri.Query.Contains("pageToken=token%20%2B%2F", StringComparison.Ordinal)) throw new Exception("Gemini-Seitencursor fehlt.");
            return Json("""{"models":[{"name":"models/embedding-next","supportedGenerationMethods":["embedContent"]}]}""");
        })))
        {
            var result = await new ModelCatalogClient(http).ListAsync("gemini", key);
            if (result.Count != 2 || result.Any(m => m.Id.StartsWith("models/")) || !result.Any(m => m.Details.Contains("embedContent"))) throw new Exception("Gemini-Modellliste oder Funktionen unvollständig.");
        }
        foreach (string invalid in new[] { "{}", "{\"data\":[]}", "{\"data\":[{\"id\":\"a\"}],\"has_more\":true,\"last_id\":\"again\"}" })
        {
            using var http = new HttpClient(new Stub((_, _) => Json(invalid)));
            bool failed = false;
            try { await new ModelCatalogClient(http).ListAsync("anthropic", key); } catch (InvalidDataException) { failed = true; }
            if (!failed) throw new Exception("Unvollständige Modellliste wurde als vollständig akzeptiert.");
        }
        using (var http = new HttpClient(new Stub((_, _) => new HttpResponseMessage(HttpStatusCode.Unauthorized) { Content = new StringContent(key) })))
        {
            try { await new ModelCatalogClient(http).ListAsync("openai", key); throw new Exception("Ungültiger Schlüssel wurde akzeptiert."); }
            catch (InvalidOperationException e) { if (e.Message.Contains(key)) throw new Exception("Schlüssel in Modellfehlermeldung."); }
        }
    }
}
