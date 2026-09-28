namespace Origo.Bifrost.Reference;

using Origo.Bifrost;

/// <summary>
/// The ONE thing a dependent app adds to Foundation's Bifrost Setup page: a single action in
/// group Apps (plus its promoted actionref). No fields, no groups, no notifications.
/// </summary>
pageextension 90012 "Ref Setup Action" extends "Setup ori"
{
    actions
    {
        addlast(Apps)
        {
            action(BifrostReferenceSetup)
            {
                ApplicationArea = All;
                Caption = 'Bifrost Reference', Comment = 'is-IS=Bifrost Reference';
                ToolTip = 'Open the setup of the Bifrost Reference app.', Comment = 'is-IS=Opna uppsetningu forritsins Bifrost Reference.';
                Image = Setup;
                RunObject = page "Ref Setup";
            }
        }
        addlast(Category_Apps)
        {
            actionref(BifrostReferenceSetup_Promoted; BifrostReferenceSetup)
            {
            }
        }
    }
}
