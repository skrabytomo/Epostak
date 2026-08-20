object FormMain: TFormMain
  Left = 150
  Top = 60
  Width = 900
  Height = 700
  Caption = 'Epostak SAPI-SK - Send + Receive'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 10
    Top = 12
    Width = 49
    Height = 13
    Caption = 'Base URL'
  end
  object Label2: TLabel
    Left = 400
    Top = 12
    Width = 88
    Height = 13
    Caption = 'Moje Participant Id'
  end
  object Label3: TLabel
    Left = 10
    Top = 42
    Width = 35
    Height = 13
    Caption = 'ClientId'
  end
  object Label4: TLabel
    Left = 400
    Top = 42
    Width = 57
    Height = 13
    Caption = 'ClientSecret'
  end
  object Label5: TLabel
    Left = 10
    Top = 112
    Width = 184
    Height = 13
    Caption = 'XML subor (prazdne = vzorova faktura)'
  end
  object Label6: TLabel
    Left = 10
    Top = 142
    Width = 111
    Height = 13
    Caption = 'Prijemca (Participant Id)'
  end
  object Label7: TLabel
    Left = 10
    Top = 182
    Width = 26
    Height = 13
    Caption = 'Inbox'
  end
  object Label8: TLabel
    Left = 10
    Top = 462
    Width = 114
    Height = 13
    Caption = 'Priecinok na stahovanie'
  end
  object edtBaseURL: TEdit
    Left = 60
    Top = 9
    Width = 330
    Height = 21
    TabOrder = 0
  end
  object edtParticipantId: TEdit
    Left = 495
    Top = 9
    Width = 200
    Height = 21
    TabOrder = 1
  end
  object edtClientId: TEdit
    Left = 60
    Top = 39
    Width = 330
    Height = 21
    TabOrder = 2
  end
  object edtClientSecret: TEdit
    Left = 495
    Top = 39
    Width = 380
    Height = 21
    TabOrder = 3
  end
  object btnSaveConfig: TButton
    Left = 10
    Top = 70
    Width = 100
    Height = 25
    Caption = 'Ulozit config'
    TabOrder = 4
    OnClick = btnSaveConfigClick
  end
  object btnUseFirmA: TButton
    Left = 120
    Top = 70
    Width = 130
    Height = 25
    Caption = 'Demo: Firma A (send)'
    TabOrder = 5
    OnClick = btnUseFirmAClick
  end
  object btnUseFirmB: TButton
    Left = 260
    Top = 70
    Width = 130
    Height = 25
    Caption = 'Demo: Firma B (recv)'
    TabOrder = 6
    OnClick = btnUseFirmBClick
  end
  object edtXMLFile: TEdit
    Left = 10
    Top = 128
    Width = 600
    Height = 21
    TabOrder = 7
  end
  object btnBrowseXML: TButton
    Left = 620
    Top = 126
    Width = 100
    Height = 25
    Caption = 'Prehladavat...'
    TabOrder = 8
    OnClick = btnBrowseXMLClick
  end
  object edtReceiverId: TEdit
    Left = 150
    Top = 158
    Width = 250
    Height = 21
    TabOrder = 9
  end
  object btnSend: TButton
    Left = 620
    Top = 156
    Width = 100
    Height = 25
    Caption = 'ODOSLAT'
    TabOrder = 10
    OnClick = btnSendClick
  end
  object lvInbox: TListView
    Left = 10
    Top = 200
    Width = 860
    Height = 250
    Columns = <>
    MultiSelect = True
    ReadOnly = True
    RowSelect = True
    TabOrder = 11
    ViewStyle = vsReport
  end
  object edtSaveFolder: TEdit
    Left = 130
    Top = 459
    Width = 420
    Height = 21
    TabOrder = 12
  end
  object btnBrowseFolder: TButton
    Left = 560
    Top = 457
    Width = 100
    Height = 25
    Caption = 'Prehladavat...'
    TabOrder = 13
    OnClick = btnBrowseFolderClick
  end
  object btnCheckInbox: TButton
    Left = 10
    Top = 490
    Width = 130
    Height = 28
    Caption = 'Skontrolovat inbox'
    TabOrder = 14
    OnClick = btnCheckInboxClick
  end
  object btnDownloadSelected: TButton
    Left = 150
    Top = 490
    Width = 150
    Height = 28
    Caption = 'Stiahnut vybrany'
    TabOrder = 15
    OnClick = btnDownloadSelectedClick
  end
  object btnAcknowledgeSelected: TButton
    Left = 310
    Top = 490
    Width = 150
    Height = 28
    Caption = 'Potvrdit vsetky vybrate'
    TabOrder = 16
    OnClick = btnAcknowledgeSelectedClick
  end
  object memLog: TMemo
    Left = 10
    Top = 530
    Width = 860
    Height = 150
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'Consolas'
    Font.Style = []
    ParentFont = False
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 17
    WordWrap = False
  end
  object dlgOpenXML: TOpenDialog
    Left = 820
    Top = 10
  end
end
