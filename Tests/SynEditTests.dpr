program SynEditTests;

{$APPTYPE CONSOLE}
{$STRONGLINKTYPES ON}

uses
  // FastMM5 FIRST, as the memory manager the per-test leak check measures ( GllDUnitX.SuiteRunner )
  FastMM5,
  System.SysUtils,
  DUnitX.TestFramework,
  GllDUnitX.SuiteRunner,
  // Every highlighter unit is linked explicitly: each registers itself from its
  // own initialization section, so a unit that is not linked is simply absent
  // from GetPlaceableHighlighters and would be silently skipped by the tests.
  // SynHighlighterManager is deliberately absent - it is a design-time manager
  // that pulls in DesignIntf, and it registers no placeable highlighter.
  SynHighlighterADSP21xx in '..\Source\Highlighters\SynHighlighterADSP21xx.pas',
  SynHighlighterAWK in '..\Source\Highlighters\SynHighlighterAWK.pas',
  SynHighlighterAsm in '..\Source\Highlighters\SynHighlighterAsm.pas',
  SynHighlighterAsmX86_64 in '..\Source\Highlighters\SynHighlighterAsmX86_64.pas',
  SynHighlighterAutoIt in '..\Source\Highlighters\SynHighlighterAutoIt.pas',
  SynHighlighterBaan in '..\Source\Highlighters\SynHighlighterBaan.pas',
  SynHighlighterBat in '..\Source\Highlighters\SynHighlighterBat.pas',
  SynHighlighterCAC in '..\Source\Highlighters\SynHighlighterCAC.pas',
  SynHighlighterCPM in '..\Source\Highlighters\SynHighlighterCPM.pas',
  SynHighlighterCS in '..\Source\Highlighters\SynHighlighterCS.pas',
  SynHighlighterCache in '..\Source\Highlighters\SynHighlighterCache.pas',
  SynHighlighterCobol in '..\Source\Highlighters\SynHighlighterCobol.pas',
  SynHighlighterCpp in '..\Source\Highlighters\SynHighlighterCpp.pas',
  SynHighlighterCss in '..\Source\Highlighters\SynHighlighterCss.pas',
  SynHighlighterDOT in '..\Source\Highlighters\SynHighlighterDOT.pas',
  SynHighlighterDWS in '..\Source\Highlighters\SynHighlighterDWS.pas',
  SynHighlighterDelphi in '..\Source\Highlighters\SynHighlighterDelphi.pas',
  SynHighlighterDfm in '..\Source\Highlighters\SynHighlighterDfm.pas',
  SynHighlighterDml in '..\Source\Highlighters\SynHighlighterDml.pas',
  SynHighlighterDockerfile in '..\Source\Highlighters\SynHighlighterDockerfile.pas',
  SynHighlighterENV in '..\Source\Highlighters\SynHighlighterENV.pas',
  SynHighlighterEiffel in '..\Source\Highlighters\SynHighlighterEiffel.pas',
  SynHighlighterErlang in '..\Source\Highlighters\SynHighlighterErlang.pas',
  SynHighlighterFortran in '..\Source\Highlighters\SynHighlighterFortran.pas',
  SynHighlighterFoxpro in '..\Source\Highlighters\SynHighlighterFoxpro.pas',
  SynHighlighterGWS in '..\Source\Highlighters\SynHighlighterGWS.pas',
  SynHighlighterGalaxy in '..\Source\Highlighters\SynHighlighterGalaxy.pas',
  SynHighlighterGeneral in '..\Source\Highlighters\SynHighlighterGeneral.pas',
  SynHighlighterGo in '..\Source\Highlighters\SynHighlighterGo.pas',
  SynHighlighterHC11 in '..\Source\Highlighters\SynHighlighterHC11.pas',
  SynHighlighterHCL in '..\Source\Highlighters\SynHighlighterHCL.pas',
  SynHighlighterHP48 in '..\Source\Highlighters\SynHighlighterHP48.pas',
  SynHighlighterHaskell in '..\Source\Highlighters\SynHighlighterHaskell.pas',
  SynHighlighterHtml in '..\Source\Highlighters\SynHighlighterHtml.pas',
  SynHighlighterIDL in '..\Source\Highlighters\SynHighlighterIDL.pas',
  SynHighlighterIni in '..\Source\Highlighters\SynHighlighterIni.pas',
  SynHighlighterInno in '..\Source\Highlighters\SynHighlighterInno.pas',
  SynHighlighterJSON in '..\Source\Highlighters\SynHighlighterJSON.pas',
  SynHighlighterJScript in '..\Source\Highlighters\SynHighlighterJScript.pas',
  SynHighlighterJava in '..\Source\Highlighters\SynHighlighterJava.pas',
  SynHighlighterKix in '..\Source\Highlighters\SynHighlighterKix.pas',
  SynHighlighterKotlin in '..\Source\Highlighters\SynHighlighterKotlin.pas',
  SynHighlighterLDraw in '..\Source\Highlighters\SynHighlighterLDraw.pas',
  SynHighlighterLLVM in '..\Source\Highlighters\SynHighlighterLLVM.pas',
  SynHighlighterLua in '..\Source\Highlighters\SynHighlighterLua.pas',
  SynHighlighterM3 in '..\Source\Highlighters\SynHighlighterM3.pas',
  SynHighlighterMakefile in '..\Source\Highlighters\SynHighlighterMakefile.pas',
  SynHighlighterMarkdown in '..\Source\Highlighters\SynHighlighterMarkdown.pas',
  SynHighlighterMatlab in '..\Source\Highlighters\SynHighlighterMatlab.pas',
  SynHighlighterModelica in '..\Source\Highlighters\SynHighlighterModelica.pas',
  SynHighlighterMsg in '..\Source\Highlighters\SynHighlighterMsg.pas',
  SynHighlighterMulti in '..\Source\Highlighters\SynHighlighterMulti.pas',
  SynHighlighterNSIS in '..\Source\Highlighters\SynHighlighterNSIS.pas',
  SynHighlighterOmni in '..\Source\Highlighters\SynHighlighterOmni.pas',
  SynHighlighterPHP in '..\Source\Highlighters\SynHighlighterPHP.pas',
  SynHighlighterPas in '..\Source\Highlighters\SynHighlighterPas.pas',
  SynHighlighterPerl in '..\Source\Highlighters\SynHighlighterPerl.pas',
  SynHighlighterPowerShell in '..\Source\Highlighters\SynHighlighterPowerShell.pas',
  SynHighlighterProgress in '..\Source\Highlighters\SynHighlighterProgress.pas',
  SynHighlighterPython in '..\Source\Highlighters\SynHighlighterPython.pas',
  SynHighlighterRC in '..\Source\Highlighters\SynHighlighterRC.pas',
  SynHighlighterRegistry in '..\Source\Highlighters\SynHighlighterRegistry.pas',
  SynHighlighterRexx in '..\Source\Highlighters\SynHighlighterRexx.pas',
  SynHighlighterRuby in '..\Source\Highlighters\SynHighlighterRuby.pas',
  SynHighlighterRust in '..\Source\Highlighters\SynHighlighterRust.pas',
  SynHighlighterSDD in '..\Source\Highlighters\SynHighlighterSDD.pas',
  SynHighlighterSQL in '..\Source\Highlighters\SynHighlighterSQL.pas',
  SynHighlighterST in '..\Source\Highlighters\SynHighlighterST.pas',
  SynHighlighterSml in '..\Source\Highlighters\SynHighlighterSml.pas',
  SynHighlighterSwift in '..\Source\Highlighters\SynHighlighterSwift.pas',
  SynHighlighterTOML in '..\Source\Highlighters\SynHighlighterTOML.pas',
  SynHighlighterTclTk in '..\Source\Highlighters\SynHighlighterTclTk.pas',
  SynHighlighterTeX in '..\Source\Highlighters\SynHighlighterTeX.pas',
  SynHighlighterTypeScript in '..\Source\Highlighters\SynHighlighterTypeScript.pas',
  SynHighlighterUNIXShellScript in '..\Source\Highlighters\SynHighlighterUNIXShellScript.pas',
  SynHighlighterURI in '..\Source\Highlighters\SynHighlighterURI.pas',
  SynHighlighterUnreal in '..\Source\Highlighters\SynHighlighterUnreal.pas',
  SynHighlighterVB in '..\Source\Highlighters\SynHighlighterVB.pas',
  SynHighlighterVBScript in '..\Source\Highlighters\SynHighlighterVBScript.pas',
  SynHighlighterVrml97 in '..\Source\Highlighters\SynHighlighterVrml97.pas',
  SynHighlighterWebIDL in '..\Source\Highlighters\SynHighlighterWebIDL.pas',
  SynHighlighterWebStencils in '..\Source\Highlighters\SynHighlighterWebStencils.pas',
  SynHighlighterXML in '..\Source\Highlighters\SynHighlighterXML.pas',
  SynHighlighterYAML in '..\Source\Highlighters\SynHighlighterYAML.pas',
  TestAsmX86_64 in 'TestAsmX86_64.pas',
  TestEditorColours in 'TestEditorColours.pas',
  TestHighlighterContract in 'TestHighlighterContract.pas',
  TestTextBuffer in 'TestTextBuffer.pas',
  TestWordNavigation in 'TestWordNavigation.pas';

begin

  // Every test is checked for memory leaks by GllDUnitX.SuiteRunner: a warm-up pass, the measured pass under FastMM5,
  // then a re-run of each flagged test; only a leak that repeats counts.
  try
    // Our gllDUnitX fork defaults Assert.IgnoreCaseDefault to True, so a two-argument Assert.AreEqual on strings
    // IGNORES CASE and nothing at the call site says so.  This suite is strict by construction; a test that genuinely
    // does not care about case must pass True explicitly.
    Assert.IgnoreCaseDefault := False;

    var oOptions := TGllSuiteOptions.Defaults;
    // The old runner turned FailsOnNoAsserts off: kept.
    oOptions.FailsOnNoAsserts := False;

    // DUnitX's command line ( an unknown option exits 251 ), RTTI discovery as well as each unit's explicit
    // registration ( the fork dedupes a fixture registered both ways ), the console and NUnit XML loggers
    // ( <exeDir>\<exeBaseName>-results.xml unless --xml names a folder ), and the GITLAK exit code: 0 all passed;
    // n = failures + errors ( warm-up failures and confirmed leaks included ), clamped to 249; 250 no tests found ( an empty run must never read as success );
    // 251 the runner itself raised.
    RunGllSuite( oOptions );

    {$IFNDEF CI}
    if TDUnitX.Options.ExitBehavior = TDUnitXExitBehavior.Pause then
    begin
      System.Write( 'Done.. press <Enter> key to quit.' );
      System.Readln;
    end;
    {$ENDIF}
  except
    on E: Exception do
    begin
      System.Writeln( 'Runner error  : ', E.ClassName, ': ', E.Message );
      System.ExitCode := 251;
    end;
  end;

end.
