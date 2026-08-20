object FormTest: TFormTest
  Left = 200
  Top = 100
  Width = 800
  Height = 500
  Caption = 'Epostak SAPI-SK Test'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  PixelsPerInch = 96
  TextHeight = 13
  object BtnRun: TButton
    Left = 10
    Top = 10
    Width = 120
    Height = 30
    Caption = 'Spustit test'
    TabOrder = 0
    OnClick = BtnRunClick
  end
  object Memo: TMemo
    Left = 10
    Top = 50
    Width = 765
    Height = 400
    Anchors = [akLeft, akTop, akRight, akBottom]
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -12
    Font.Name = 'Consolas'
    Font.Style = []
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 1
    WordWrap = False
  end
end
