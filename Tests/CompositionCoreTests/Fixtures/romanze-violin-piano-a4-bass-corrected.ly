\version "2.24.0"

\header {
  title = "Romanze"
  subtitle = "im Stil von Max Bruch"
  instrument = "für Violine und Klavier"
  composer = "Komponiert im spätromantischen Stil"
  tagline = ##f
}

\paper {
  #(set-paper-size "a4")
  top-margin = 1.5\cm
  bottom-margin = 1.5\cm
  left-margin = 2\cm
  right-margin = 1.5\cm
  indent = 2\cm
}

global = {
  \key g \minor
  \time 4/4
  \tempo "Adagio ma non troppo, molto espressivo" 4 = 56
}

violinMusic = \relative c' {
  \global
  
  % Teil A: Sonore Kantilene auf der G-Saite, rhapsodisch
  R1\p |
  r2 r4 d4\mf^\markup { \italic "sul G, molto espressivo" } ( |
  g2.~ g8 a16 bes |
  a4. fis8 d4. ) d8( |
  bes'4. a8 g4 \tuplet 3/2 { g8 a bes } |
  c2~ c8 ) a( fis d |
  bes'4. a8 g4 ) g16( a bes g |
  ees4. d8 c4. ) c8\<( |
  d8. ees16 fis8. g16 a4. bes16 c |
  bes2\! a4 ) r8 d,\p( |
  g2. \tuplet 3/2 { a8 bes c } |
  d2.\< ) d8( ees16 f\! |
  \tuplet 3/2 { g8\f f ees } \tuplet 3/2 { d c bes } a4. g8 |
  g2 ) r2 |

  % Teil B: Es-Dur / B-Dur, fließend, leidenschaftliche Steigerung, Doppelgriffe
  \key ees \major
  bes'2.\mp^\markup { \italic "dolce ed appassionato" } ( g8 ees |
  f4. g8 aes2 ) |
  bes4.( c8 \tuplet 3/2 { d8 ees f } g8. f16 |
  ees2 d4 ) r8 bes\mf( |
  ees4.\< f8 g4. aes8\! |
  <d, bes'>2.\f ) <ees c'>8( <f d'> |
  <g ees'>4. <f d'>8 <ees c'>4 <d bes'> |
  <e c'>2 <f d'>4 ) r8 f\f( |
  \tuplet 3/2 { bes8\< c d } \tuplet 3/2 { ees f g } aes4.\ff ) g16( f |
  g8. ees16 bes8. g16 ees4. ) g8( |
  <aes, f'>4.\> <g ees'>8 <f d'>4 <ees c'>\! |
  <d b'>2.\dim <c a'!>4 |

  % Rückleitung und Verklingen in verklärtem G-Dur
  \key g \major
  <b g'>1\p ) |
  r4 d^\markup { \italic "tranquillo e dolce" }( g4. b8 |
  d2. e8 d |
  b4. a8 g4. e8 |
  d2. ) e8( fis |
  g4.\< a8 b4 d\! |
  g2.\mf\> fis8 e |
  d4.\p b8 g4. ) e8( |
  d2~ d8 e fis a |
  g1~\pp |
  <g d'>1\ppp\fermata ) \bar "|."
}

pianoRH = \relative c' {
  \global
  
  % Teil A: Dunkle, synkopierte Akkorde
  r8 <bes d g>8\p( <bes d g>4~ <bes d g>8 <bes d g> <bes d g>4) |
  r8 <bes d g>( <bes d g>4) r8 <a c fis>( <a c fis>4) |
  r8 <bes d g>\mp( <bes d g>4) r8 <cis e g>( <cis e g>4) |
  r8 <a d fis>( <a d fis>4) r8 <a c fis>( <a c fis>4) |
  r8 <bes d g>( <bes d g>4) r8 <bes d f>( <bes d f>4) |
  r8 <g c ees>( <g c ees>4) r8 <a c fis>( <a c fis>4) |
  r8 <bes d g>( <bes d g>4) r8 <bes d g>( <bes d g>4) |
  r8 <g c ees>( <g c ees>4) r8 <g a ees'>( <g a ees'>4) |
  r8 <fis a d>\<( <fis a d>4) r8 <g a ees'>( <g a ees'>4)\! |
  r8 <g bes d>\mf( <g bes d>4) r8 <fis a d>\>( <fis a d>4)\! |
  r8 <bes d g>\p( <bes d g>4) r8 <c ees g>( <c ees g>4) |
  r8 <bes d g>\<( <bes d g>4) r8 <bes f' aes>( <bes f' aes>4)\! |
  r8 <bes ees g>\f( <bes ees g>4) r8 <a c fis>( <a c fis>4) |
  r8 <bes d g>\>( <bes d g> <a c fis> <bes d g>4)\! r4 |

  % Teil B: Fließende Sechzehntel-Arpeggien
  \key ees \major
  \tuplet 6/4 { r16\mp g( bes ees bes g } \tuplet 6/4 { r16 g bes ees bes g } \tuplet 6/4 { r16 g bes ees bes g } \tuplet 6/4 { r16 g bes ees bes g) } |
  \tuplet 6/4 { r16 aes( c f c aes } \tuplet 6/4 { r16 aes c f c aes } \tuplet 6/4 { r16 aes b f' b, aes } \tuplet 6/4 { r16 aes b f' b, aes) } |
  \tuplet 6/4 { r16 g( bes ees bes g } \tuplet 6/4 { r16 aes c ees c aes } \tuplet 6/4 { r16 g bes ees bes g } \tuplet 6/4 { r16 g b f' b, g) } |
  \tuplet 6/4 { r16 g( c ees c g } \tuplet 6/4 { r16 ges c ees c ges } \tuplet 6/4 { r16 f bes d bes f } \tuplet 6/4 { r16 f aes d aes f) } |
  \tuplet 6/4 { r16\mf g\<( bes ees bes g } \tuplet 6/4 { r16 aes c f c aes } \tuplet 6/4 { r16 bes ees g ees bes } \tuplet 6/4 { r16 c ees aes ees c)\! } |
  \tuplet 6/4 { r16\f bes( d f d bes } \tuplet 6/4 { r16 bes d f d bes } \tuplet 6/4 { r16 bes d aes' d, bes } \tuplet 6/4 { r16 bes d aes' d, bes) } |
  \tuplet 6/4 { r16 bes( ees g ees bes } \tuplet 6/4 { r16 bes d g d bes } \tuplet 6/4 { r16 c ees g ees c } \tuplet 6/4 { r16 bes d g d bes) } |
  \tuplet 6/4 { r16 bes( c g' c, bes } \tuplet 6/4 { r16 bes c e c bes } \tuplet 6/4 { r16 a c f c a } \tuplet 6/4 { r16 bes d f d bes) } |
  \tuplet 6/4 { r16 bes\<( d f d bes } \tuplet 6/4 { r16 bes ees g ees bes } \tuplet 6/4 { r16\ff c f aes f c } \tuplet 6/4 { r16 c f aes f c)\! } |
  \tuplet 6/4 { r16 bes( ees g ees bes } \tuplet 6/4 { r16 bes ees g ees bes } \tuplet 6/4 { r16 bes ees g ees bes } \tuplet 6/4 { r16 bes ees g ees bes) } |
  \tuplet 6/4 { r16\dim aes( c f c aes } \tuplet 6/4 { r16 g c ees c g } \tuplet 6/4 { r16 f aes d aes f } \tuplet 6/4 { r16 ees g c g ees) } |
  \tuplet 6/4 { r16 d( g b g d } \tuplet 6/4 { r16 d g b g d } \tuplet 6/4 { r16 d fis a fis d } \tuplet 6/4 { r16 d fis a fis d)\! } |

  % Teil C: Verklärtes G-Dur
  \key g \major
  \tuplet 3/2 { r8\p d( g } \tuplet 3/2 { b d b } \tuplet 3/2 { g d g } \tuplet 3/2 { b d b) } |
  \tuplet 3/2 { r8 d,( g } \tuplet 3/2 { b d b } \tuplet 3/2 { g d g } \tuplet 3/2 { b d b) } |
  \tuplet 3/2 { r8 fis( a } \tuplet 3/2 { c d c } \tuplet 3/2 { b g b } \tuplet 3/2 { d g d) } |
  \tuplet 3/2 { r8 g,( b } \tuplet 3/2 { e g e } \tuplet 3/2 { c g c } \tuplet 3/2 { e g e) } |
  \tuplet 3/2 { r8 g,( b } \tuplet 3/2 { d g d } \tuplet 3/2 { c a c } \tuplet 3/2 { fis a fis) } |
  \tuplet 3/2 { r8 g,\<( b } \tuplet 3/2 { d g d } \tuplet 3/2 { g, b d } \tuplet 3/2 { g b g)\! } |
  \tuplet 3/2 { r8\mf a,\>( c } \tuplet 3/2 { e a e } \tuplet 3/2 { a, c e } \tuplet 3/2 { a c a)\! } |
  \tuplet 3/2 { r8\p g,( b } \tuplet 3/2 { d g d } \tuplet 3/2 { g, c e } \tuplet 3/2 { g c g) } |
  \tuplet 3/2 { r8 fis,( a } \tuplet 3/2 { c d c } \tuplet 3/2 { a fis a } \tuplet 3/2 { c d c) } |
  \tuplet 3/2 { r8\pp g( b } \tuplet 3/2 { d g b } d2~ |
  <g, b d g>1\ppp\fermata ) \bar "|."
}

pianoLH = \absolute {
  \global
  \clef bass
  % Bassoktaven korrigiert; Tonklassen, Notenwerte und Akkorde bleiben erhalten.
  <g,, g,>2 <g, d> |
  <g,, g,>2 <d a> |
  <g,, g,>2 <a,, a,> |
  <d, d>2 <c, c> |
  <bes,, bes,>2 <g,, g,> |
  <c, c>2 <d, d> |
  <g,, g,>2 <f,! f!> |
  <ees, ees>2 <c, c> |
  <d, d>2 <c, c> |
  <d, d>2 <d,, d,> |
  <g,, g,>2 <ees, ees> |
  <bes,, bes,>2 <bes, aes> |
  <ees, ees>2 <d, d> |
  <g,, g,>2~ <g,, g,>4 r4 |
  \key ees \major
  <ees, bes,>1 |
  <f, c>2 <d, b,> |
  <ees, bes,>4 <c, aes,> <bes,, g,> <g,, d,> |
  <c, c>2 <bes,, bes,> |
  <ees, ees>4 <d, d> <c, c> <aes,, aes,> |
  <bes,, bes,>2 <aes, bes,> |
  <g, ees>4 <f, d> <ees, c> <d, bes,> |
  <c, g,>2 <f,, f,>4 <bes,, bes,> |
  <aes,, aes,> <g,, g,> <f,, f,>2 |
  <ees, ees>1 |
  <f, f>4 <ees, ees> <d, d> <c, c> |
  <g,, g,>2 <d, d> |
  \key g \major
  <g,, d, b,>1 |
  <g,, d, b,>1 |
  <g,, d, a,>2 <g,, d, g,> |
  <e, b,>2 <c, g,> |
  <d, g,>2 <d, a,> |
  <e, b,>2 <b,, g,> |
  <c, a,>1 |
  <d, g,>2 <c, g,> |
  <d, a, d>1 |
  <g,, d, g,>1~ |
  <g,, d, g,>1\fermata \bar "|."
}

\score {
  <<
    \new Staff \with {
      instrumentName = "Violine"
      shortInstrumentName = "Vl."
      midiInstrument = "violin"
    } \violinMusic

    \new PianoStaff \with {
      instrumentName = "Klavier"
      shortInstrumentName = "Klav."
      midiInstrument = "acoustic grand"
    } <<
      \new Staff = "rh" \pianoRH
      \new Staff = "lh" \pianoLH
    >>
  >>
  \layout {
    \context {
      \Score
      \override SpacingSpanner.base-shortest-duration = #(ly:make-moment 1/16)
    }
  }
  \midi { }
}
