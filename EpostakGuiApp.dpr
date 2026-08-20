program EpostakGuiApp;

uses
  Forms,
  UTestForm in 'UTestForm.pas' {FormTest};

begin
  Application.Initialize;
  Application.CreateForm(TFormTest, FormTest);
  Application.Run;
end.
