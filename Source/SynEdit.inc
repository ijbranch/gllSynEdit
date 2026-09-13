{------------------------------------------------------------------------------}
{ Common compiler defines                                                      }
{ (remove the dot in front of a define to enable it)                           }
{------------------------------------------------------------------------------}

{$B-,H+} // defaults are short evaluation of boolean values and long strings

{.$DEFINE SYN_DEVELOPMENT_CHECKS} // additional tests for debugging
{$IFDEF SYN_DEVELOPMENT_CHECKS}
  {$R+,Q+,S+,T+}
{$ENDIF}

{------------------------------------------------------------------------------}
{ SynEditJedi.inc was removed here. It detected compilers from Delphi 1 (VER80)}
{ to Delphi 13 (VER370) in 2,160 lines and 502 defines, and this library used  }
{ none of the symbols it produced: the whole runtime package (135 units,       }
{ 221,548 lines) compiles clean against an empty stub of it. It also carried   }
{ the only deliberately unbalanced directive nesting in the tree, which is an  }
{ obstacle to any mechanical pass over the sources.                            }
{------------------------------------------------------------------------------}

{------------------------------------------------------------------------------}
{  Please change this to suit your needs (to activate an option remove the dot }
{  in front of a DEFINE)                                                       }
{------------------------------------------------------------------------------}

// "Heredoc" syntax highlighting
// If you enable the following statement and use highlighter(s) that have
// support for "Heredoc" strings as scheme(s) in SynMultiSyn, you must
// implement your own SynMultiSyn OnCustomRange event handler in order to
// properly store Range State information
{.$DEFINE SYN_HEREDOC}


