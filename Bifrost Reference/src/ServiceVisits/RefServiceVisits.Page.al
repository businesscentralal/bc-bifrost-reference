namespace Origo.Bifrost.Reference;

/// <summary>
/// Plain list page so a person can see what Reference.ServiceVisit.Create wrote.
/// The UI and the message type share the table; the message type never opens this page.
/// </summary>
page 90010 "Ref Service Visits"
{
    Caption = 'Reference Service Visits', Comment = 'is-IS=Þjónustuheimsóknir (sýnidæmi)';
    PageType = List;
    SourceTable = "Ref Service Visit";
    UsageCategory = Lists;
    ApplicationArea = All;
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Visits)
            {
                field("Entry No."; Rec."Entry No.")
                {
                    ToolTip = 'The number of the visit entry.', Comment = 'is-IS=Númer heimsóknarfærslunnar.';
                }
                field("Customer No."; Rec."Customer No.")
                {
                    ToolTip = 'The customer that was visited.', Comment = 'is-IS=Viðskiptamaðurinn sem var heimsóttur.';
                }
                field("Visit Date"; Rec."Visit Date")
                {
                    ToolTip = 'The date of the visit.', Comment = 'is-IS=Dagsetning heimsóknarinnar.';
                }
                field(Hours; Rec.Hours)
                {
                    ToolTip = 'The hours spent.', Comment = 'is-IS=Klukkustundir sem fóru í heimsóknina.';
                }
                field(Description; Rec.Description)
                {
                    ToolTip = 'A short description of the visit.', Comment = 'is-IS=Stutt lýsing á heimsókninni.';
                }
                field("External Id"; Rec."External Id")
                {
                    ToolTip = 'The caller''s own id for the visit, used to make retries safe.', Comment = 'is-IS=Eigið auðkenni sendanda fyrir heimsóknina, notað til að gera endurtekningar öruggar.';
                }
            }
        }
    }
}
