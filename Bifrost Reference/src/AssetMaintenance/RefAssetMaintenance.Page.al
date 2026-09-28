namespace Origo.Bifrost.Reference;

/// <summary>
/// Plain list page so a person can see what Reference.AssetMaintenance.Create wrote.
/// The UI and the message type share the table; the message type never opens this page.
/// </summary>
page 90010 "Ref Asset Maintenance"
{
    Caption = 'Reference Asset Maintenance', Comment = 'is-IS=Viðhald eigna (sýnidæmi)';
    PageType = List;
    SourceTable = "Ref Asset Maintenance";
    UsageCategory = Lists;
    ApplicationArea = All;
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Entries)
            {
                field("Entry No."; Rec."Entry No.")
                {
                    ToolTip = 'The number of the maintenance entry.', Comment = 'is-IS=Númer viðhaldsfærslunnar.';
                }
                field("FA No."; Rec."FA No.")
                {
                    ToolTip = 'The fixed asset the maintenance was done on.', Comment = 'is-IS=Eignin sem viðhaldið var unnið á.';
                }
                field("Maintenance Date"; Rec."Maintenance Date")
                {
                    ToolTip = 'The date the maintenance was done.', Comment = 'is-IS=Dagsetningin sem viðhaldið var unnið.';
                }
                field(Hours; Rec.Hours)
                {
                    ToolTip = 'The hours spent on the maintenance.', Comment = 'is-IS=Klukkustundir sem fóru í viðhaldið.';
                }
                field(Description; Rec.Description)
                {
                    ToolTip = 'A short note on the work done.', Comment = 'is-IS=Stutt lýsing á verkinu sem var unnið.';
                }
                field("External Id"; Rec."External Id")
                {
                    ToolTip = 'The caller''s own id for the entry, used to make retries safe.', Comment = 'is-IS=Eigið auðkenni sendanda fyrir færsluna, notað til að gera endurtekningar öruggar.';
                }
            }
        }
    }
}
