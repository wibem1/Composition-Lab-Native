using System.Diagnostics;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;

namespace CompositionLab;

internal sealed partial class MainForm
{
    LilyPondCompiler? lilyCompiler;
    LilyPondOutput? currentLilyPond;
    string? currentLilyPondPreviewUri;
    LilyPondCompiler Engraver => lilyCompiler ??= new(Path.Combine(dataDirectory, "LilyPondCache"));

    static string AppliedLilyPondText(JsonObject document) => document["lilyPondSource"]?.GetValue<string>() ?? document["concept"]?.GetValue<string>() ?? "";
    string EditableLilyPondText(JsonObject document) => Regex.IsMatch(composition.Text, @"\\(?:version|score)\b|```(?:lilypond|ly)\b", RegexOptions.IgnoreCase) ? composition.Text : AppliedLilyPondText(document);

    async Task ApplyLilyPondEditsAsync()
    {
        if (busy || Current == null) return;
        var document = Current;
        int generation = displayGeneration;
        string editorText = composition.Text;
        string music = EditableLilyPondText(document);
        try
        {
            pending = new CancellationTokenSource(); SetBusy(true);
            var source = new JsonObject { ["assignment"] = document["assignment"]?.DeepClone(), ["provider"] = document["provider"]?.DeepClone(),
                ["model"] = document["model"]?.DeepClone(), ["estimatedCostUSD"] = document["costUSD"]?.DeepClone(),
                ["inputTokens"] = document["inputTokens"]?.DeepClone(), ["outputTokens"] = document["outputTokens"]?.DeepClone() };
            var result = await CompileCheckedCompositionAsync(music, source, pending.Token, updateDiagnostic: false);
            // A different slot or a new edit must never receive an older result.
            if (!ReferenceEquals(Current, document) || generation != displayGeneration || composition.Text != editorText)
            { SetStatus("Der Quelltext oder das Stück wurde inzwischen geändert. Bitte erneut aktualisieren."); return; }
            SaveScoreUndoSnapshot(document);
            document["lilyPondSource"] = result["composition"]!.DeepClone();
            document["description"] = result["composition"]!.DeepClone();
            foreach (string field in new[] { "octaveReview", "originalLilyPond" }) if (result[field] != null) document[field] = result[field]!.DeepClone();
            document["costUSD"] = result["estimatedCostUSD"]?.DeepClone();
            document["inputTokens"] = result["inputTokens"]?.DeepClone(); document["outputTokens"] = result["outputTokens"]?.DeepClone();
            document["directLilyPond"] = true;
            document["sourceMidiData"] = result["sourceMidiData"]!.DeepClone();
            document["score"] = result["score"]!.DeepClone();
            document["title"] = result["score"]!["ti"]!.DeepClone();
            result["entryPoint"] = "edited-lilypond";
            lastDiagnostic = result.DeepClone().AsObject(); UpdateDiagnostic();
            RememberPiece(document); RefreshSlots(); SaveLocalState();
            await DisplayCurrentAsync();
            SetMusicStatus(result, result["octaveReview"]?["status"]?.GetValue<string>() == "corrected" ? "Oktavlagen korrigiert und geprüft. Notation und MIDI aktualisiert." : "Bearbeiteter LilyPond-Code übernommen. Notation und MIDI aktualisiert.");
        }
        catch (OperationCanceledException) { SetStatus("Aktualisierung abgebrochen. Die letzte gültige Ausgabe bleibt erhalten."); }
        catch (Exception e)
        {
            if (e is RegisterRepairException failure) lastDiagnostic = failure.Report.DeepClone().AsObject();
            else lastDiagnostic = new JsonObject { ["format"] = "composition-lab-native-diagnostic", ["interfaceVersion"] = Version,
                ["entryPoint"] = "edited-lilypond", ["stage"] = "failed", ["composition"] = music, ["error"] = e.Message,
                ["conversionAICalls"] = 0, ["lastValidSource"] = AppliedLilyPondText(document) };
            UpdateDiagnostic();
            throw;
        }
        finally { pending?.Dispose(); pending = null; SetBusy(false); }
    }

    async Task<JsonObject> CompileCompositionAsync(string music, JsonObject source, CancellationToken token, bool updateDiagnostic = true)
    {
        SetStatus("LilyPond erzeugt MIDI und Originalnoten lokal …");
        string notation = ExtractLilyPond(music);
        var watch = Stopwatch.StartNew();
        var compiled = await Engraver.CompileAsync(notation, token);
        string title = Regex.Match(notation, "\\btitle\\s*=\\s*\"([^\"]+)\"") is { Success: true } m ? m.Groups[1].Value : "Komposition";
        var imported = await core.RunAsync(new JsonObject { ["operation"] = "import-midi", ["data"] = Convert.ToBase64String(compiled.Midi), ["title"] = title }, token);
        var score = imported["score"]!.DeepClone().AsObject(); score["ti"] = title;
        watch.Stop();
        var result = new JsonObject
        {
            ["format"] = "composition-lab-native-diagnostic", ["interfaceVersion"] = Version,
            ["assignment"] = source["assignment"]?.DeepClone(), ["provider"] = source["provider"]?.DeepClone(),
            ["model"] = source["model"]?.DeepClone(), ["reasoning"] = source["reasoning"]?.DeepClone(),
            ["composition"] = music, ["score"] = score, ["sourceMidiData"] = Convert.ToBase64String(compiled.Midi),
            ["directLilyPond"] = true, ["stage"] = "completed", ["conversionEngine"] = "LilyPond " + LilyPondCompiler.Version,
            ["conversionMilliseconds"] = Math.Round(watch.Elapsed.TotalMilliseconds), ["engravingMilliseconds"] = Math.Round(compiled.Milliseconds),
            ["engravingCacheHit"] = compiled.Cached, ["engravingPageCount"] = compiled.Pages.Length,
            ["engravingLog"] = compiled.Log, ["conversionAICalls"] = 0,
            ["translationInputTokens"] = 0, ["translationOutputTokens"] = 0,
            ["inputTokens"] = source["inputTokens"]?.DeepClone() ?? JsonValue.Create(0),
            ["outputTokens"] = source["outputTokens"]?.DeepClone() ?? JsonValue.Create(0),
            ["estimatedCostUSD"] = source["estimatedCostUSD"]?.DeepClone() ?? JsonValue.Create(0d),
            ["sourceDiagnostic"] = source.DeepClone()
        };
        if (updateDiagnostic) { lastDiagnostic = result.DeepClone().AsObject(); UpdateDiagnostic(); }
        return result;
    }

    async Task RebuildOriginalAsync()
    {
        if (busy) return;
        var document = Current ?? throw new InvalidOperationException("Kein Stück geladen.");
        string music = document["concept"]?.GetValue<string>() ?? "";
        if (!ContainsFinishedMusic(music)) throw new InvalidOperationException("Dieses Stück enthält kein LilyPond-Original.");
        int destination = Array.FindIndex(documents, d => d == null);
        if (destination < 0) throw new InvalidOperationException("Bitte einen Slot für die Originalausgabe freimachen. Die bisherige Fassung bleibt erhalten.");
        try
        {
            pending = new CancellationTokenSource(); SetBusy(true);
            var input = new JsonObject { ["assignment"] = document["assignment"]?.DeepClone(), ["provider"] = document["provider"]?.DeepClone(), ["model"] = document["model"]?.DeepClone(),
                ["estimatedCostUSD"] = document["costUSD"]?.DeepClone(), ["inputTokens"] = document["inputTokens"]?.DeepClone(), ["outputTokens"] = document["outputTokens"]?.DeepClone() };
            var result = await CompileCheckedCompositionAsync(music, input, pending.Token);
            await AcceptCompositionAsync(result, destination, document["assignment"]?.GetValue<string>() ?? "", document["provider"]?.GetValue<string>() ?? activeProvider, document["model"]?.GetValue<string>() ?? SelectedModelId);
            SetMusicStatus(result, "Originalnoten und Original-MIDI in Slot " + (destination + 1) + ". Die bisherige Fassung bleibt erhalten.");
        }
        finally { pending?.Dispose(); pending = null; SetBusy(false); }
    }

    // LilyPond's point-and-click links contain source.ly:line:column.
    // Only source locations from the locally generated score are accepted.
    void SelectLilyPondSource(JsonNode message)
    {
        if (Current == null || currentLilyPond == null) return;
        int line = (int?)message["line"] ?? 0, column = (int?)message["column"] ?? 0;
        int endLine = (int?)message["endLine"] ?? line;
        int endColumn = (int?)message["endColumn"] ?? column;
        if (line < 1 || column < 1 || endLine < 1 || endColumn < 1) return;
        string source = EditableLilyPondText(Current);
        var lines = source.Split('\n');
        int Index(int l, int c)
        {
            if (l > lines.Length) return -1;
            int offset = 0;
            for (int i = 0; i < l - 1; i++) offset += lines[i].Length + 1;
            return offset + Math.Min(c - 1, lines[l - 1].Length);
        }
        int start = Index(line, column), end = Index(endLine, endColumn);
        if (start < 0 || end < 0) return;
        if (end < start) (start, end) = (end, start);
        tabs.SelectedIndex = 0;
        if (composition.Text != source)
        {
            loadingIdea = true;
            try { composition.Text = source; }
            finally { loadingIdea = false; }
        }
        composition.Focus();
        composition.SelectionStart = Math.Min(start, composition.TextLength);
        composition.SelectionLength = Math.Min(Math.Max(1, end - start + 1), composition.TextLength - composition.SelectionStart);
        composition.ScrollToCaret();
        SetStatus("LilyPond-Quelltext markiert: Zeile " + line + " bis " + endLine +
            ". Tonhöhen im Editor korrigieren und anschließend Notation aktualisieren.");
    }

    void RenderLilyPond()
    {
        if (!webReady || currentLilyPond == null) return;
        // Render SVG inline, not inside <img>: point-and-click anchors need
        // to be actual DOM nodes to be clickable and selectable.
        string pages = JsonSerializer.Serialize(currentLilyPond.Pages);
        string html = """
            <!doctype html><html><head><meta charset="utf-8">
            <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'">
            <style>html,body{margin:0;background:#eee}#score{padding:12px}.page{display:block;width:100%;background:white;margin:0 auto 12px}.page svg{display:block;width:100%;height:auto}.page[hidden]{display:none}
            .page a{cursor:crosshair}.page a:hover{outline:1px solid #bd7d00;outline-offset:3px}.page a.selected{outline:2px solid #e99a10;outline-offset:4px}
            #selection{position:sticky;top:0;z-index:10;padding:8px;background:#fff;border-bottom:1px solid #ccc;display:flex;gap:12px;align-items:center;font:13px Segoe UI,sans-serif}
            #selection button{padding:6px 12px;cursor:pointer}
            @media print{#selection{display:none}}
            @media print{html,body{background:white}#score{padding:0}.page,.page[hidden]{display:block!important;width:100%!important;margin:0;break-after:page}.page:last-child{break-after:auto}}</style></head>
            <body><div id="selection"><span id="selectionCount">Note anklicken oder mit gedrückter Maus über die Passage ziehen.</span><button id="openSelection" disabled>Auswahl im Editor öffnen</button><button id="clearSelection">Auswahl aufheben</button></div><div id="score"></div><script>
            const images=PAGES_VALUE; let currentPage=1,scale=100;
            const host=document.getElementById('score');
            images.forEach(source=>{const page=document.createElement('div');page.className='page';
              const parsed=new DOMParser().parseFromString(source,'image/svg+xml');
              const svg=parsed.documentElement;
              // LilyPond SVGs are generated locally. Drop active SVG content.
              svg.querySelectorAll('script,foreignObject').forEach(n=>n.remove());
              page.appendChild(document.importNode(svg,true));host.appendChild(page)});
            function render(){Array.from(host.children).forEach((page,i)=>{page.hidden=i!==currentPage-1;page.style.width=scale+'%';page.style.maxWidth='none'});window.chrome.webview.postMessage({page:currentPage,count:images.length,zoom:scale})}
            function page(delta){currentPage=Math.max(1,Math.min(images.length,currentPage+delta));render();window.scrollTo(0,0)}
            function zoom(delta){scale=Math.max(40,Math.min(300,scale+delta));render()}
            const chosen=new Map();
            const count=document.getElementById('selectionCount');
            const open=document.getElementById('openSelection');
            const linkLocation=a=>{
              if(!a)return null;
              const href=a.getAttribute('href')||a.getAttribute('xlink:href')||'';
              const m=href.match(/source\.ly:(\d+):(\d+):(\d+)/i);
              return m?{line:Number(m[1]),column:Number(m[3])}:null;
            };
            const links=Array.from(host.querySelectorAll('a')).filter(a=>linkLocation(a));
            const nearestLink=target=>target && target.closest ? target.closest('a') : null;
            function updateSelection(){count.textContent=chosen.size+' Noten markiert';open.disabled=chosen.size===0}
            function clear(){chosen.forEach((_,a)=>a.classList.remove('selected'));chosen.clear();updateSelection()}
            function setNote(a,on){const loc=linkLocation(a);if(!loc)return;
              if(on){chosen.set(a,loc);a.classList.add('selected')}
              else {chosen.delete(a);a.classList.remove('selected')}
              updateSelection();
            }
            function markRange(first,last){
              const a=links.indexOf(first),b=links.indexOf(last);
              if(a<0||b<0)return;
              clear();
              for(let i=Math.min(a,b);i<=Math.max(a,b);i++)setNote(links[i],true);
            }
            function openEditor(){
              if(!chosen.size)return;
              const notes=Array.from(chosen.values()).sort((a,b)=>a.line-b.line||a.column-b.column);
              const first=notes[0],last=notes[notes.length-1];
              window.chrome.webview.postMessage({action:'select-source',line:first.line,column:first.column,endLine:last.line,endColumn:last.column});
            }
            open.addEventListener('click',openEditor);
            document.getElementById('clearSelection').addEventListener('click',clear);
            // Single click toggles notes. Dragging across anchored notes selects
            // a contiguous range, including beamed passages and multiple notes.
            let dragStart=null,dragEnd=null,didDrag=false,suppressClick=false;
            host.addEventListener('pointerdown',event=>{
              if(event.button!==0)return;
              const a=nearestLink(event.target);if(!linkLocation(a))return;
              dragStart=a;dragEnd=a;didDrag=false;
              event.preventDefault();
            });
            host.addEventListener('pointermove',event=>{
              if(!dragStart || !(event.buttons&1))return;
              const at=document.elementFromPoint(event.clientX,event.clientY);
              const a=nearestLink(at);
              if(!linkLocation(a)||a===dragEnd)return;
              dragEnd=a;didDrag=true;markRange(dragStart,dragEnd);
              event.preventDefault();
            });
            document.addEventListener('pointerup',event=>{
              if(!dragStart)return;
              const last=dragEnd,first=dragStart,wasDrag=didDrag;
              dragStart=null;dragEnd=null;didDrag=false;
              suppressClick=true;
              if(wasDrag)markRange(first,last);
              else setNote(first,!chosen.has(first));
              event.preventDefault();
            });
            host.addEventListener('click',event=>{
              const a=nearestLink(event.target);
              if(!linkLocation(a))return;
              event.preventDefault();
              if(suppressClick){suppressClick=false;return}
              // Also supports keyboard-activated links and synthetic clicks.
              setNote(a,!chosen.has(a));
            });
            host.addEventListener('dragstart',event=>event.preventDefault());
            render();
            </script></body></html>
            """;
        string content = html.Replace("PAGES_VALUE", pages);
        string folder = Path.Combine(dataDirectory, "LilyPondPreviews"); Directory.CreateDirectory(folder);
        string hash = Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(Encoding.UTF8.GetBytes(content)));
        string path = Path.Combine(folder, hash + ".html");
        if (!File.Exists(path)) AtomicFile.WriteText(path, content);
        currentLilyPondPreviewUri = new Uri(path).AbsoluteUri + "?view=" + Guid.NewGuid().ToString("N");
        web.CoreWebView2.Navigate(currentLilyPondPreviewUri);
    }
}
