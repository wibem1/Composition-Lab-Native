\version "2.24.0"

\header {
  title = "Pastorale"
  subtitle = "für Violine und Violoncello"
  composer = "Komposition im klassischen Stil"
  tagline = ##f
}

global = {
  \key f \major
  \time 6/8
  \tempo "Andante pastorale" 4. = 52
}

violinMusic = \relative c' {
  \global
  \clef treble

  % --- TEIL A: Sanfte Hirtenmelodie ---
  % T. 1-4: Thema 1 (p, dolce)
  f4(\p^\markup { \italic "dolce e cantabile" } a8 c4 a8 |
  d4 c8 a4 f8 |
  g4 a8 bes4 g8 |
  a4.~ a4) r8 |

  % T. 5-8: Weiterführung und Aufschwung
  f4( a8 c4 f8 |
  e4 d8 c4 a8 |
  bes4\< d8 g,4 bes8 |
  a4.\> g4) r8\! |

  % T. 9-12: Thema in höherer Lage
  a'4(\mf c8 f4 c8 |
  d4 c8 a4 f8 |
  g4\> a8 bes8 a g |
  a4.~ a4)\p r8 |

  % T. 13-16: Kadenzierung zur Dominante
  b4(\< c8 d4 b8 |
  c4\! a8 f4 d8 |
  c4\> f8 e4 d8 |
  c4.~ c4)\p r8 \bar "||"

  % --- TEIL B: Rollentausch (Violine figuriert, Cello singt) ---
  % T. 17-20: Fließende Begleitung in F-Dur / B-Dur
  r8^\markup { \italic "leggiero" } c(\p f a f c) |
  r8 d( f bes f d) |
  r8 c( f a f c) |
  r8 c( e g e c) |

  % T. 21-24: Modulation nach d-Moll
  r8 d( f a f d) |
  r8 d(\< g bes g d)\! |
  r8 d( f a f d) |
  r8 cis(\> e a e cis)\! |

  % T. 25-28: Rückführung und Verdichtung
  r8 d(\p f bes f d) |
  r8 c( f a f c) |
  r8 bes( d g d bes) |
  r8 c(\< e bes' g e)\! |

  % T. 29-32: Überleitung zur Reprise
  c'8(\mf a f c' a f) |
  d'( bes f d' bes f) |
  c'(\> a f e g bes |
  a8 g f e d c)\! \bar "||"

  % --- TEIL A': Reprise ---
  % T. 33-36: Hauptthema
  f4(\p^\markup { \italic "tempo primo, dolce" } a8 c4 a8 |
  d4 c8 a4 f8 |
  g4 a8 bes4 g8 |
  a4.~ a4) r8 |

  % T. 37-40: Lyrische Steigerung zum Höhepunkt
  a4(\< c8 f4 a8 |
  g4\! f8 d4 bes8 |
  a4 c8 \grace { d16( } c8)\> bes g |
  f4.~ f4\! r8 |

  % --- CODA: Friedlicher Ausklang ---
  % T. 41-46
  d'4(\pp c8 bes4 d8 |
  c4 a8 f4) r8 |
  g4( a8 bes4 g8 |
  a4 f'8 c4 a8 |
  f4.~ f4) r8 |
  <a, f'>2.\ppp\fermata \bar "|."
}

celloMusic = \relative c {
  \global
  \clef bass

  % --- TEIL A: Bordun-Quinten und wiegende Bässe ---
  % T. 1-4: Klassischer Pastorale-Bordun
  <f, c'>2.\p^\markup { \italic "con morbidezza" } ~ |
  <f c'>2. |
  <f d'>4. <f c'>4. |
  <f c'>4( a8 c4 a8) |

  % T. 5-8
  <f c'>2. |
  <a e'>4. d4( c8) |
  bes4(\< a8 g4)\! f8 |
  c'4.~(\> c4 bes8)\! |

  % T. 9-12
  <f c'>4.\mp <f c'>4. |
  <f d'>4. <f c'>4. |
  <e c'>4.\> <c c'>4. |
  f8(\p c' a f4) r8 |

  % T. 13-16: Weg zur Dominante C-Dur
  g8(\< d' g, f d' g,)\! |
  e8( c' e, f4) a8 |
  g4.\> <g, g'>4. |
  c8(\p g' e c4) r8 \bar "||"

  % --- TEIL B: Cello übernimmt die Kantilene in der Tenorlage ---
  % T. 17-20
  \clef tenor
  a''4(\mf^\markup { \italic "espressivo e cantabile" } g8 f4 a8 |
  bes4 a8 f4 d8 |
  c4 f8 a4 c,8 |
  g'4.~ g4) r8 |

  % T. 21-24: Moll-Eintrübung
  f4( e8 d4 f8 |
  g4\< a8 bes4\! g8 |
  a4 f8 d4 f8 |
  e4.~ e4)\> r8\! |

  % T. 25-28: Sequenzierung
  d4(\mp f8 bes4 d,8 |
  c4 f8 a4 c,8 |
  bes4 d8 g4 bes,8 |
  c4\< e8 g4\! bes8) |

  % T. 29-32: Abstieg zurück in die Basslage
  a4(\mf c8 f4 a,8 |
  bes4 d8 f4) r8 |
  \clef bass
  c,4.(\> c,4. |
  f4) r8 r4 r8\! \bar "||"

  % --- TEIL A': Reprise ---
  % T. 33-36: Rückkehr des Borduns
  <f c'>2.\p ~ |
  <f c'>2. |
  <f d'>4. <f c'>4. |
  <f c'>8( c' a f4) r8 |

  % T. 37-40: Sanfte Gegenstimme
  <f c'>4.(\< <a, f'>4.)\! |
  bes8( f' d bes4) d8 |
  c4.(\> c,4.) |
  f8(\! c' a f4) r8 |

  % --- CODA: Verklingen über Orgelpunkt F ---
  % T. 41-46
  <f bes>2.\pp |
  <f a>2. |
  <f d'>4. <f bes>4. |
  <f c'>2. ~ |
  <f c'>4( a8 c4 a8) |
  <f, c' f>2.\ppp\fermata \bar "|."
}

\score {
  \new StaffGroup <<
    \new Staff \with {
      instrumentName = "Violine"
      shortInstrumentName = "Vl."
      midiInstrument = "violin"
    } \violinMusic

    \new Staff \with {
      instrumentName = "Violoncello"
      shortInstrumentName = "Vc."
      midiInstrument = "cello"
    } \celloMusic
  >>

  \layout {
    \context {
      \Score
      \override SpacingSpanner.base-shortest-duration = #(ly:make-moment 1/16)
    }
  }

  \midi {
    \tempo 4. = 52
  }
}
