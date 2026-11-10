% =============================================================================
%  xum_review.cls — XMUM Assignment & Review Report Template
%  Xiamen University Malaysia
%
%  Compiler : XeLaTeX (required for Consolas monospace font)
%  Based on : article (A4, 12pt)
%
%  CLASS OPTIONS
%  ─────────────
%  [turnitin]   Disable all headers and footers.
%               Use this option when compiling the version you upload to
%               Turnitin, to prevent the repeated header/footer text
%               ("XIAMEN UNIVERSITY MALAYSIA", "Page X of Y") from being
%               flagged as similarity matches.
%
%               Usage:  \documentclass[turnitin]{xum_review}
%
%  Usage (normal):  \documentclass{xum_review}
% =============================================================================

\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{xum_review}[2025/01/01 XMUM Assignment Template]

% ---------------------------------------------------------------------------
%  Class options
% ---------------------------------------------------------------------------
\newif\if@turnitin
\@turnitinfalse
\DeclareOption{turnitin}{\@turnitintrue}
\DeclareOption*{\PassOptionsToClass{\CurrentOption}{article}}
\ProcessOptions\relax

% ---------------------------------------------------------------------------
%  Base class
% ---------------------------------------------------------------------------
\LoadClass[a4paper,12pt]{article}

% ---------------------------------------------------------------------------
%  Core packages (loaded early — others may depend on these)
% ---------------------------------------------------------------------------
\RequirePackage[utf8]{inputenc}         % UTF-8 source encoding
\RequirePackage[T1]{fontenc}            % Proper output font encoding
\RequirePackage{geometry}               % Page margins
\RequirePackage{fancyhdr}               % Custom headers and footers
\RequirePackage{setspace}               % Line spacing
\RequirePackage{parskip}                % Paragraph spacing (no indent, adds vspace)
\RequirePackage{etoolbox}               % Toolbox for LaTeX programming
\RequirePackage{lastpage}               % Provides \pageref{LastPage}

% ---------------------------------------------------------------------------
%  URL and hyphenation
% ---------------------------------------------------------------------------
\RequirePackage{xurl}                   % Better URL line-breaking
\RequirePackage[htt]{hyphenat}          % Allow line-breaking inside \texttt{}

% Allow line breaks at more characters inside URLs
\def\UrlBreaks{\do\.\do\@\do\\\do\/\do\!\do\_\do\|\do\;\do\>%
  \do\]\do\)\do\,\do\?\do\'\do+\do\=\do\#\do\(\do\[}

% \code{} — an inline code command that breaks lines gracefully
\newcommand{\code}[1]{{\ttfamily\path{#1}}}

% ---------------------------------------------------------------------------
%  PDF and hyperlinks
% ---------------------------------------------------------------------------
\RequirePackage[colorlinks=true,
                linkcolor=black,
                citecolor=black,
                urlcolor=cyan]{hyperref}

\hypersetup{
    bookmarks  = true,
    pdftitle   = {XMUM Assignment},
    pdfauthor  = {Xiamen University Malaysia}
}

% ---------------------------------------------------------------------------
%  Page geometry
% ---------------------------------------------------------------------------
\geometry{
    top        = 2.5cm,
    bottom     = 2.5cm,
    left       = 2.5cm,
    right      = 2.5cm,
    headheight = 15pt
}

% ---------------------------------------------------------------------------
%  Headers and footers
%
%  The [turnitin] class option disables all headers and footers globally.
%  This prevents repeated header/footer text from being flagged by Turnitin
%  as similarity matches.
% ---------------------------------------------------------------------------
\if@turnitin
    % Turnitin mode: suppress all headers and footers, permanently.
    % \pagestyle and \thispagestyle are neutralised so that any explicit
    % calls in main.tex (e.g. \pagestyle{fancy} after the ToC) cannot
    % accidentally re-enable them.
    \AtBeginDocument{%
        \pagestyle{empty}%
        \let\pagestyle\@gobble%      % future \pagestyle{...} calls → no-op
        \let\thispagestyle\@gobble%  % future \thispagestyle{...} calls → no-op
    }
\else
    % Normal mode: XMUM-style header and page number footer
    \pagestyle{fancy}
    \fancyhf{}
    \fancyhead[C]{XIAMEN UNIVERSITY MALAYSIA}
    \fancyfoot[C]{Page \thepage\ of \pageref{LastPage}}
    \renewcommand{\headrulewidth}{0pt}
    \renewcommand{\footrulewidth}{0pt}

    % Plain style (used on the first page of the document body)
    \fancypagestyle{plain}{
        \fancyhf{}
        \fancyhead[C]{XIAMEN UNIVERSITY MALAYSIA}
        \fancyfoot[C]{}
        \renewcommand{\headrulewidth}{0pt}
        \renewcommand{\footrulewidth}{0pt}
    }
\fi

% ---------------------------------------------------------------------------
%  Spacing and paragraph formatting
% ---------------------------------------------------------------------------
\onehalfspacing                         % 1.5× line spacing
\setlength{\parskip}{0.5\baselineskip}  % Half-line gap between paragraphs
\setlength{\parindent}{0pt}             % No first-line indentation

% ---------------------------------------------------------------------------
%  Title block (\maketitle)
% ---------------------------------------------------------------------------
\renewcommand{\maketitle}{
    \begin{center}
        {\LARGE\bfseries\@title\par}
        \vspace{1em}
        {\large\@author\par}
        \vspace{0.5em}
        {\large\@date\par}
    \end{center}
    \vspace{2em}
}

% ---------------------------------------------------------------------------
%  Table of contents
% ---------------------------------------------------------------------------
\RequirePackage{tocloft}

\renewcommand{\contentsname}{Contents}

% Dot leaders for all three heading levels
\renewcommand{\cftsecleader}{\cftdotfill{\cftdotsep}}
\renewcommand{\cftsubsecleader}{\cftdotfill{\cftdotsep}}
\renewcommand{\cftsubsubsecleader}{\cftdotfill{\cftdotsep}}

% ---------------------------------------------------------------------------
%  Section heading numbering
% ---------------------------------------------------------------------------
% subsection shows as "1.1", "1.2" etc.
\renewcommand{\thesubsection}{\arabic{section}.\arabic{subsection}}

% ---------------------------------------------------------------------------
%  Section heading appearance
% ---------------------------------------------------------------------------
\renewcommand{\section}{\@startsection{section}{1}{\z@}%
    {-3.5ex \@plus -1ex \@minus -.2ex}%
    {2.3ex \@plus.2ex}%
    {\normalfont\Large\bfseries}}

\renewcommand{\subsection}{\@startsection{subsection}{2}{\z@}%
    {-3.25ex\@plus -1ex \@minus -.2ex}%
    {1.5ex \@plus .2ex}%
    {\normalfont\large\bfseries}}

\renewcommand{\subsubsection}{\@startsection{subsubsection}{3}{\z@}%
    {-3.25ex\@plus -1ex \@minus -.2ex}%
    {1.5ex \@plus .2ex}%
    {\normalfont\normalsize\bfseries}}

% ---------------------------------------------------------------------------
%  Figure and table numbering (reset per section, numbered as "1.1", "1.2"…)
% ---------------------------------------------------------------------------
\renewcommand{\thefigure}{\thesection.\arabic{figure}}
\renewcommand{\thetable}{\thesection.\arabic{table}}
\@addtoreset{figure}{section}
\@addtoreset{table}{section}

% ---------------------------------------------------------------------------
%  Captions
% ---------------------------------------------------------------------------
\RequirePackage{caption}
\captionsetup{
    font      = small,
    labelfont = bf,
    textfont  = it,
    margin    = 10pt
}

% ---------------------------------------------------------------------------
%  Bibliography (APA style via apacite)
% ---------------------------------------------------------------------------
\RequirePackage[natbibapa]{apacite}
\bibliographystyle{apacite}
\renewcommand{\refname}{References}

% Add "References" to the table of contents automatically
\renewcommand{\bibsection}{%
    \section*{\refname}%
    \addcontentsline{toc}{section}{\refname}%
}

% ---------------------------------------------------------------------------
%  Additional utility packages
% ---------------------------------------------------------------------------
\RequirePackage{titlesec}               % Section title formatting utilities
\RequirePackage{csquotes}               % Context-sensitive quotation marks
\RequirePackage{xcolor}                 % Colour support
\RequirePackage{float}                  % [H] float placement
\RequirePackage{graphicx}               % \includegraphics
\RequirePackage{amsmath}                % Mathematical typesetting
\RequirePackage{adjustbox}              % Shrink oversized content to text width
\RequirePackage{cleveref}               % Smart cross-references (\cref, \Cref)
\RequirePackage{fontspec}               % XeLaTeX font selection
\RequirePackage{pdfpages}               % Insert external PDF pages
\RequirePackage{longtable}              % Multi-page tables
\RequirePackage{booktabs}               % Professional table rules (\toprule etc.)
\RequirePackage{listings}               % Code listings

% ---------------------------------------------------------------------------
%  Monospace font (XeLaTeX only)
% ---------------------------------------------------------------------------
\setmonofont{Consolas}[Scale=0.9]

% ---------------------------------------------------------------------------
%  Code listing environments
%  All environments share a common visual style:
%    - Light grey background
%    - Line numbers on the left
%    - Syntax-highlighted keywords / strings / comments
% ---------------------------------------------------------------------------

% --- Python ----------------------------------------------------------------
\lstnewenvironment{python}[1][]{%
    \lstset{
        language        = Python,
        basicstyle      = \ttfamily\footnotesize,
        numbers         = left,
        numberstyle     = \ttfamily\color[RGB]{130,130,130},
        numbersep       = 5pt,
        backgroundcolor = \color[RGB]{245,245,245},
        frame           = none,
        breaklines      = true,
        breakindent     = 10pt,
        keywordstyle    = \color[RGB]{255,119,0},
        morekeywords    = {as, self},
        deletekeywords  = {print},
        keywordstyle    = [2]\color[RGB]{144,0,144},
        morekeywords    = [2]{print},
        stringstyle     = \color[RGB]{0,170,0},
        commentstyle    = \color[RGB]{221,0,0},
        showstringspaces= false,
        #1
    }%
}{}

% --- SQL -------------------------------------------------------------------
\lstnewenvironment{sql}[1][]{%
    \lstset{
        language         = SQL,
        basicstyle       = \ttfamily\footnotesize,
        numbers          = left,
        numberstyle      = \ttfamily\color[RGB]{130,130,130},
        numbersep        = 5pt,
        backgroundcolor  = \color[RGB]{245,245,245},
        frame            = none,
        breaklines       = true,
        breakindent      = 10pt,
        keywordstyle     = \color[RGB]{255,119,0},
        morekeywords     = {EXPLAIN,ANALYZE,PARTITION,OVER,WINDOW,LATERAL,MATERIALIZED,ORDINALITY},
        keywordstyle     = [2]\color[RGB]{144,0,144},
        morekeywords     = [2]{COUNT,SUM,AVG,MAX,MIN,DISTINCT,CAST,COALESCE,NULLIF,CASE,WHEN,THEN,ELSE,END},
        keywordstyle     = [3]\color[RGB]{0,102,204},
        morekeywords     = [3]{TEXT,INTEGER,BIGINT,SERIAL,VARCHAR,CHAR,DATE,TIME,TIMESTAMP,BOOLEAN,NUMERIC,DECIMAL,REAL,DOUBLE},
        stringstyle      = \color[RGB]{0,170,0},
        commentstyle     = \color[RGB]{221,0,0},
        showstringspaces = false,
        #1
    }%
}{}

% --- JSON ------------------------------------------------------------------
\lstnewenvironment{json}[1][]{%
    \lstset{
        language         = ,
        basicstyle       = \ttfamily\footnotesize,
        numbers          = left,
        numberstyle      = \ttfamily\color[RGB]{130,130,130},
        numbersep        = 5pt,
        backgroundcolor  = \color[RGB]{245,245,245},
        frame            = none,
        breaklines       = true,
        breakindent      = 10pt,
        stringstyle      = \color[RGB]{0,170,0},
        commentstyle     = \color[RGB]{221,0,0},
        literate         =
            {:}{{\color[RGB]{255,119,0}{:}}}{1}
            {,}{{\color[RGB]{255,119,0}{,}}}{1}
            {\{}{{\color[RGB]{0,0,255}{\{}}}{1}
            {\}}{{\color[RGB]{0,0,255}{\}}}}{1}
            {[}{{\color[RGB]{0,0,255}{[}}}{1}
            {]}{{\color[RGB]{0,0,255}{]}}}{1}
            {true}{{\color[RGB]{144,0,144}{true}}}{4}
            {false}{{\color[RGB]{144,0,144}{false}}}{5}
            {null}{{\color[RGB]{144,0,144}{null}}}{4},
        showstringspaces = false,
        morestring       = [b]",
        morestring       = [b]',
        #1
    }%
}{}

% --- Windows Command Prompt -------------------------------------------------
\lstnewenvironment{cmd}[1][]{%
    \lstset{
        language         = command.com,
        basicstyle       = \ttfamily\footnotesize,
        numbers          = left,
        numberstyle      = \ttfamily\color[RGB]{170,170,170},
        numbersep        = 5pt,
        backgroundcolor  = \color[RGB]{245,245,245},
        frame            = none,
        breaklines       = true,
        breakindent      = 10pt,
        stringstyle      = \color[RGB]{255,255,0},
        keywordstyle     = \color[RGB]{0,255,255},
        commentstyle     = \color[RGB]{0,170,0},
        showstringspaces = false,
        morestring       = [b]",
        morestring       = [b]',
        #1
    }%
}{}

% --- HTML ------------------------------------------------------------------
\lstnewenvironment{html}[1][]{%
    \lstset{
        language         = HTML,
        basicstyle       = \ttfamily\footnotesize,
        numbers          = left,
        numberstyle      = \ttfamily\color[RGB]{130,130,130},
        numbersep        = 5pt,
        backgroundcolor  = \color[RGB]{245,245,245},
        frame            = none,
        breaklines       = true,
        breakindent      = 10pt,
        keywordstyle     = \color[RGB]{0,0,255},
        stringstyle      = \color[RGB]{0,170,0},
        commentstyle     = \color[RGB]{221,0,0},
        identifierstyle  = \color[RGB]{255,119,0},
        showstringspaces = false,
        tabsize          = 2,
        #1
    }%
}{}

% --- JavaScript ------------------------------------------------------------
\lstnewenvironment{javascript}[1][]{%
    \lstset{
        language         = Java,
        basicstyle       = \ttfamily\footnotesize,
        numbers          = left,
        numberstyle      = \ttfamily\color[RGB]{130,130,130},
        numbersep        = 5pt,
        backgroundcolor  = \color[RGB]{245,245,245},
        frame            = none,
        breaklines       = true,
        breakindent      = 10pt,
        keywordstyle     = [2]\color[RGB]{255,119,0},
        morekeywords     = {var,let,const,function,return,if,else,for,while,do,switch,
                            case,break,continue,try,catch,finally,throw,new,this,typeof,
                            instanceof,in,of,async,await,class,extends,super,static,
                            import,export,default,from,as},
        morekeywords     = [2]{console,document,window,alert,prompt,confirm,
                            getElementById,createElement,appendChild,addEventListener,
                            fetch,Promise,JSON,Array,Object,String,Number,Boolean,
                            Date,RegExp,Math,parseInt,parseFloat,isNaN,
                            setTimeout,setInterval,clearTimeout,clearInterval},
        stringstyle      = \color[RGB]{0,170,0},
        commentstyle     = \color[RGB]{221,0,0},
        identifierstyle  = \color[RGB]{0,0,0},
        showstringspaces = false,
        tabsize          = 2,
        morecomment      = [l]{//},
        morecomment      = [s]{/*}{*/},
        morestring       = [b]",
        morestring       = [b]',
        morestring       = [b]`,
        #1
    }%
}{}

% --- C++ -------------------------------------------------------------------
\lstnewenvironment{cpp}[1][]{%
    \lstset{
        language         = C++,
        basicstyle       = \ttfamily\footnotesize,
        numbers          = left,
        numberstyle      = \ttfamily\color[RGB]{130,130,130},
        numbersep        = 5pt,
        backgroundcolor  = \color[RGB]{245,245,245},
        frame            = single,
        framerule        = 0.5pt,
        frameround       = ffff,
        rulecolor        = \color[RGB]{229,230,232},
        framesep         = 2pt,
        breaklines       = true,
        breakindent      = 10pt,
        keywordstyle     = \color[RGB]{255,119,0},
        stringstyle      = \color[RGB]{0,170,0},
        commentstyle     = \color[RGB]{221,0,0},
        showstringspaces = false,
        #1
    }%
}{}

% --- Generic (custom header label) -----------------------------------------
%  Usage: \begin{codewithheader}[lstset options]{Header Text}
\newcommand{\codeheader}[1]{%
    \vspace{0.5em}
    \noindent
    \colorbox[RGB]{248,249,250}{%
        \begin{minipage}{\textwidth}
        \vspace{0.2em}
        \hspace{0.8em}
        \color[RGB]{88,88,88}%
        \textbf{\textsf{#1}}%
        \vspace{0.2em}
        \end{minipage}
    }%
    \vspace{-0.1em}
}

\lstnewenvironment{codewithheader}[2][]{%
    \codeheader{#2}
    \lstset{
        basicstyle       = \ttfamily\footnotesize,
        numbers          = left,
        numberstyle      = \tiny\color{gray},
        numbersep        = 8pt,
        frame            = single,
        framerule        = 0.5pt,
        frameround       = ffff,
        rulecolor        = \color[RGB]{229,230,232},
        framesep         = 2pt,
        backgroundcolor  = \color[RGB]{255,255,255},
        breaklines       = true,
        breakindent      = 10pt,
        keywordstyle     = \color[RGB]{255,119,0},
        stringstyle      = \color[RGB]{0,170,0},
        commentstyle     = \color[RGB]{221,0,0},
        showstringspaces = false,
        #1
    }%
}{}

% =============================================================================
\endinput