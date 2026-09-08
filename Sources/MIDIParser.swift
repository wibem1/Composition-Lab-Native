import Foundation

enum MIDIParserError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { if case .invalid(let s) = self { return s }; return "Ungültige MIDI-Datei." }
}

enum MIDIParser {
    private struct EventNote { var start:Int; var end:Int; var pitch:Int; var velocity:Int; var channel:Int }
    private struct ParsedTrack { var name=""; var notes:[EventNote]=[]; var controls:[[Double]]=[]; var programs:[Int:Int]=[:] }

    static func parse(data: Data, fallbackTitle: String) throws -> Score {
        let b=[UInt8](data); var i=0
        func u16(_ p:Int)->Int { (Int(b[p])<<8)|Int(b[p+1]) }
        func u32(_ p:Int)->Int { (Int(b[p])<<24)|(Int(b[p+1])<<16)|(Int(b[p+2])<<8)|Int(b[p+3]) }
        guard b.count>=14, String(bytes:b[0..<4],encoding:.ascii)=="MThd" else { throw MIDIParserError.invalid("Keine Standard-MIDI-Datei.") }
        let headerLen=u32(4); guard headerLen>=6, b.count>=8+headerLen else { throw MIDIParserError.invalid("Beschädigter MIDI-Kopf.") }
        let tracks=u16(10), division=u16(12)
        guard division & 0x8000 == 0, division>0 else { throw MIDIParserError.invalid("SMPTE-Zeitbasis wird nicht unterstützt.") }
        let ppq=division; i=8+headerLen
        var parsed:[ParsedTrack]=[]; var bpm=120.0; var ts=TimeSignature(n:4,d:4); var key="nicht angegeben"; var globalTitle=fallbackTitle
        for _ in 0..<tracks {
            guard i+8<=b.count, String(bytes:b[i..<i+4],encoding:.ascii)=="MTrk" else { throw MIDIParserError.invalid("Beschädigte MIDI-Spur.") }
            let len=u32(i+4); i += 8; let end=min(i+len,b.count); var pos=i; var tick=0; var running:Int?=nil; var pt=ParsedTrack(); var active:[String:[(Int,Int)]]=[:]
            func vlq(_ posRef: inout Int) throws -> Int { var v=0; var n=0; while posRef<end { let x=Int(b[posRef]); posRef+=1; v=(v<<7)|(x&0x7f); n+=1; if x&0x80==0{return v}; if n>4{break} }; throw MIDIParserError.invalid("Ungültiger MIDI-Zeitwert.") }
            while pos<end {
                tick += try vlq(&pos); if pos>=end { break }
                var status=Int(b[pos]); if status<0x80 { guard let r=running else { throw MIDIParserError.invalid("Ungültiger Running Status.") }; status=r } else { pos+=1; if status<0xF0 { running=status } }
                if status==0xFF {
                    guard pos<end else{break}; let type=Int(b[pos]); pos+=1; let l=try vlq(&pos); guard pos+l<=end else{break}; let d=Array(b[pos..<pos+l]); pos+=l
                    if type==0x03, let s=String(bytes:d,encoding:.utf8) { pt.name=s; if globalTitle==fallbackTitle && !s.isEmpty { globalTitle=s } }
                    else if type==0x51 && d.count==3 { let us=(Int(d[0])<<16)|(Int(d[1])<<8)|Int(d[2]); if us>0 { bpm=60_000_000.0/Double(us) } }
                    else if type==0x58 && d.count>=2 { ts=TimeSignature(n:Int(d[0]),d:1<<Int(d[1])) }
                    else if type==0x59 && d.count>=2 { let sf=Int(Int8(bitPattern:d[0])); let minor=d[1] != 0; let majors=[-7:"Ces-Dur",-6:"Ges-Dur",-5:"Des-Dur",-4:"As-Dur",-3:"Es-Dur",-2:"B-Dur",-1:"F-Dur",0:"C-Dur",1:"G-Dur",2:"D-Dur",3:"A-Dur",4:"E-Dur",5:"H-Dur",6:"Fis-Dur",7:"Cis-Dur"]; let minors=[-7:"as-Moll",-6:"es-Moll",-5:"b-Moll",-4:"f-Moll",-3:"c-Moll",-2:"g-Moll",-1:"d-Moll",0:"a-Moll",1:"e-Moll",2:"h-Moll",3:"fis-Moll",4:"cis-Moll",5:"gis-Moll",6:"dis-Moll",7:"ais-Moll"]; key=(minor ? minors[sf] : majors[sf]) ?? "nicht angegeben" }
                    continue
                }
                if status==0xF0 || status==0xF7 { let l=try vlq(&pos); pos=min(end,pos+l); running=nil; continue }
                let kind=status&0xF0, ch=status&0x0F; let count=(kind==0xC0 || kind==0xD0) ? 1:2; guard pos+count<=end else{break}; let a=Int(b[pos]); pos+=1; let c=count==2 ? Int(b[pos]):0; if count==2{pos+=1}
                if kind==0x90 && c>0 { active["\(ch)-\(a)",default:[]].append((tick,c)) }
                else if kind==0x80 || (kind==0x90 && c==0) { let k="\(ch)-\(a)"; if var arr=active[k], !arr.isEmpty { let x=arr.removeFirst(); active[k]=arr; pt.notes.append(EventNote(start:x.0,end:max(tick,x.0+1),pitch:a,velocity:x.1,channel:ch)) } }
                else if kind==0xB0 { pt.controls.append([Double(tick)/Double(ppq),Double(a),Double(c),Double(ch)]) }
                else if kind==0xC0 { pt.programs[ch]=a }
            }
            for (k,arr) in active { let parts=k.split(separator:"-"); guard parts.count==2, let ch=Int(parts[0]), let pitch=Int(parts[1]) else{continue}; for x in arr { pt.notes.append(EventNote(start:x.0,end:max(tick,x.0+1),pitch:pitch,velocity:x.1,channel:ch)) } }
            parsed.append(pt); i=end
        }
        var out:[Track]=[]
        for (ti,pt) in parsed.enumerated() {
            let channels=Set(pt.notes.map{$0.channel}).union(pt.programs.keys)
            for ch in channels.sorted() {
                let ns=pt.notes.filter{$0.channel==ch}.sorted{$0.start<$1.start}.map { n -> [Double] in
                    let st=Double(n.start)/Double(ppq), dur=Double(n.end-n.start)/Double(ppq); return [st,dur,Double(n.pitch),Double(n.velocity),0,1.0]
                }
                if ns.isEmpty { continue }
                let ct=pt.controls.filter{Int($0[3])==ch}.map{[$0[0],$0[1],$0[2]]}
                let base=pt.name.isEmpty ? "Spur \(ti+1)" : pt.name; let nm=channels.count>1 ? "\(base) · Kanal \(ch+1)" : base
                out.append(Track(nm:nm,ch:ch,pg:pt.programs[ch] ?? 0,nt:ns,ct:ct.isEmpty ? nil:ct))
            }
        }
        guard !out.isEmpty else { throw MIDIParserError.invalid("Die MIDI-Datei enthält keine Noten.") }
        return Score(ti:globalTitle,bpm:bpm,ts:ts,k:key,sm:"Importierte MIDI-Vorlage mit \(out.count) Spur(en).",tr:out)
    }
}
