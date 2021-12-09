<###############################
Title: CXT BOIP Creation Script
Author: TW
Original: 2021_06_17
Last Updated: 2021_07_07
	

WORK FLOW:
- Prompt User to Enter 'Y' For Document Creation From Previous Change Request or 'N' for Template

- Document Creation From Previous Change Request:
    - Prompt User to Enter Previous CNR along with New CNR
    - Prompt User to enter Previous Release Number along with New Release Number
    - Find, Copy, and Replace Previous CNR Folder & BOIPS with the latest data
    - Determine\Update The Following specific to their documents:
        - Open Prod MS Word Document, Determine\Update Doc Contents: Deployment Date(s)
        - Open QA MS Word Document, Determine\Update Doc Contents: Deployment Date(s) 
        - Open Dev MS Word Document, Determine\Update Doc Contents: Deployment Date(s)
    - Global Updates across all documents
        - Open Prod,QA, and DEv MS Word Documents, Determine\Update Doc Contents: Highlighted Text, Change Request Number, & Backout CNR


FUTURE ENHANCEMENTS
- GUI
###############################>

#Create syncronized hash table to be read across multiple runspaces
$script:syncHash = [hashtable]::Synchronized(@{})


###############
#USER VARIABLES
###############

$syncHash.boipPath = Join-Path -Path $PWD.Path -ChildPath "\files"
$syncHash.tempBoipPath = Join-Path -Path $PWD.Path -ChildPath "Files\Template\"
$syncHash.vendorUpdatesPath = "\\va01pstodfs003.corp.agp.ads\apps\Local\EMT\COTS\McKesson\ClaimsXten\v6.3\McKesson-supplied-updates"

#$syncHash.message = New-Object System.Collections.Generic.List[System.Object]

$syncHash.message

###########################
#Import External Functions#
###########################
$syncHash.functionPS1 = Join-Path -Path $PWD.Path -ChildPath "\Functions.ps1"
. $syncHash.functionPS1

#################
#   MAIN CODE   #
#################

#Load xaml function into Sessionstate object for injection into runspace
$ssGetXamlObject = Get-Content Function:\Get-XamlObject -ErrorAction Stop
$ssfeGetXamlObject = New-Object System.Management.Automation.Runspaces.SessionStateFunctionEntry -ArgumentList 'Get-XamlObject', $ssGetXamlObject

#Add Function to session state
$initialSessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
$initialSessionState.Commands.Add($ssfeGetXamlObject)

$runspace = [runspacefactory]::CreateRunspace($initialSessionState)
$powershell = [powershell]::Create()
$powershell.runspace = $runspace
$runspace.ThreadOptions = "ReuseThread"
$runspace.ApartmentState = "STA"
$runspace.Open()
$runspace.SessionStateProxy.SetVariable("syncHash",$syncHash)

[void]$PowerShell.AddScript({
    param(
        $syncHash
    )
    
    . $syncHash.functionPS1


    $wpf = Get-ChildItem -Path $PWD.Path -Filter *.xaml -file | Where-Object { $_.Name -ne 'App.xaml' } | Get-XamlObject
    $wpf.GetEnumerator() | Foreach-Object {$script:syncHash.add($_.name,$_.value)}

    #region Launch Page
    $syncHash.BtnPreviousChange.add_Click({
        $syncHash.WizardWindowFrame.NavigationService.Navigate($syncHash.prevChangePageOne)
})


$syncHash.BtnNextPageOne.add_Click({
        if(($pcValidationResult -eq $True) -and ($ccValidationResult -eq $True) -and ($prValidationResult -eq $True) -and ($prValidationResult -eq $True)){
             $syncHash.WizardWindowFrame.NavigationService.Navigate($syncHash.prevChangePageTwo)
        }
    
        if($pcValidationResult -eq $False){
            $prevChangeTextbox.BorderBrush="#ba0000"
        
            $syncHash.pcErrorDisplay.Text = "Field Required."
            $syncHash.pcErrorDisplay.Foreground="#ba0000"
            $syncHash.pcErrorDisplay.Visibility="Visible"

        }
        if($ccValidationResult -eq $False){
            $currentChangeTextbox.BorderBrush="#ba0000"
        
            $syncHash.ccErrorDisplay.Text = "Field Required."
            $syncHash.ccErrorDisplay.Foreground="#ba0000"
            $syncHash.ccErrorDisplay.Visibility="Visible"
        }
        if($prValidationResult -eq $False){
            $prevReleaseTextbox.BorderBrush="#ba0000"
        
            $syncHash.prErrorDisplay.Text = "Field Required."
            $syncHash.prErrorDisplay.Foreground="#ba0000"
            $syncHash.prErrorDisplay.Visibility="Visible"
        }
        if($prValidationResult -eq $False){
            $newReleaseTextbox.BorderBrush="#ba0000"
        
            $syncHash.crErrorDisplay.Text = "Field Required."
            $syncHash.crErrorDisplay.Foreground="#ba0000"
            $syncHash.crErrorDisplay.Visibility="Visible"
        }
    
})

#region Previous Page One
$syncHash.BtnBackPageOne.add_Click({
    $syncHash.WizardWindowFrame.NavigationService.Navigate($syncHash.launchPage)
})


$pcValidationResult = $False
$ccValidationResult = $False
$prValidationResult = $False
$crValidationResult = $False


if($syncHash.prevChangePageOne.IsInitialized){
    $prevChangeTextbox = $syncHash.TextBoxPC
    $prevChangeTextbox.Add_TextChanged({
    if (($prevChangeTextbox.Text -match '[A-Za-z]{4}[-]\w{4,}') -and (!([string]::IsNullOrEmpty($prevChangeTextbox.Text)))){
        $syncHash.prevCNR = $prevChangeTextbox.Text

        #Gets previous CNR from BoipPath defined above
        $syncHash.prevBoipPath = Join-Path -Path $syncHash.boipPath -ChildPath $syncHash.prevCNR

        If(Test-Path $syncHash.prevBoipPath)
        {
            $prevChangeTextbox.BorderBrush="#22ba00"
            
            $syncHash.pcErrorDisplay.Text = "SNOW Path Found."
            $syncHash.pcErrorDisplay.Foreground="#22ba00"
            $syncHash.pcErrorDisplay.Visibility="Visible"

            $Script:pcValidationResult = $True
            
        }else{
            
            $prevChangeTextbox.BorderBrush="#ba0000"
            
            $syncHash.pcErrorDisplay.Text = "SNOW Path Was Not Found."
            $syncHash.pcErrorDisplay.Foreground="#ba0000"
            $syncHash.pcErrorDisplay.Visibility="Visible"

            $Script:pcValidationResult = $False

        }

        
    }elseif(([string]::IsNullOrEmpty($prevChangeTextbox.Text))){
        $prevChangeTextbox.BorderBrush="#ba0000"
        
        $syncHash.pcErrorDisplay.Text = "Field Required."
        $syncHash.pcErrorDisplay.Foreground="#ba0000"
        $syncHash.pcErrorDisplay.Visibility="Visible"

        $Script:pcValidationResult = $False
    }else{
        
        $prevChangeTextbox.BorderBrush="#ba0000"
        $syncHash.pcErrorDisplay.Text = "Incorrect Format."
        $syncHash.pcErrorDisplay.Foreground="#ba0000"
        $syncHash.pcErrorDisplay.Visibility="Visible"

        $Script:pcValidationResult = $False
    }

})


    $currentChangeTextbox = $syncHash.TextBoxCC
    $currentChangeTextbox.Add_TextChanged({
        if (($currentChangeTextbox.Text -match '[A-Za-z]{4}[-]\w{4,}') -and (!([string]::IsNullOrEmpty($prevChangeTextbox.Text))) -and ($currentChangeTextbox.Text -ne $prevChangeTextbox.Text)) {
            
            $syncHash.newCNR = $currentChangeTextbox.Text
            $syncHash.currentBoipPath = Join-Path -Path $syncHash.boipPath -ChildPath $syncHash.newCNR

            if(Test-Path $syncHash.currentBoipPath){
                $currentChangeTextbox.BorderBrush="#ba0000"
        
                $syncHash.ccErrorDisplay.Text = $syncHash.newCNR + " already exist. Please try a new change number."
                $syncHash.ccErrorDisplay.Foreground="#ba0000"
                $syncHash.ccErrorDisplay.Visibility="Visible"

                $Script:ccValidationResult = $False
            }else{
                $currentChangeTextbox.BorderBrush="#22ba00"

                $syncHash.ccErrorDisplay.Text = "SNOW Path Found."
                $syncHash.ccErrorDisplay.Foreground="#22ba00"
                $syncHash.ccErrorDisplay.Visibility="Hidden"

                $Script:ccValidationResult = $True
            }    

        
        }elseif([string]::IsNullOrEmpty($currentChangeTextbox.Text)){
            $currentChangeTextbox.BorderBrush="#ba0000"
        
            $syncHash.ccErrorDisplay.Text = "Field Required."
            $syncHash.ccErrorDisplay.Foreground="#ba0000"
            $syncHash.ccErrorDisplay.Visibility="Visible"

            $Script:ccValidationResult = $False
        }elseif($currentChangeTextbox.Text -match $prevChangeTextbox.Text){
            $currentChangeTextbox.BorderBrush="#ba0000"
        
            $syncHash.ccErrorDisplay.Text = "Current and Previous Change Request Cannot Match."
            $syncHash.ccErrorDisplay.Foreground="#ba0000"
            $syncHash.ccErrorDisplay.Visibility="Visible"

            $Script:ccValidationResult = $False
        
        }else{
            $currentChangeTextbox.BorderBrush="#ba0000"
        
            $syncHash.ccErrorDisplay.Text = "Incorrect Format."
            $syncHash.ccErrorDisplay.Foreground="#ba0000"
            $syncHash.ccErrorDisplay.Visibility="Visible"

            $Script:ccValidationResult = $False

        }
    })
    
    $prevReleaseTextbox = $syncHash.TextBoxPR
    $prevReleaseTextbox.Add_TextChanged({
        if ($prevReleaseTextbox.Text -match"R\d{2,}[.]\d{1,}" -or ($prevReleaseTextbox.Text -match "R\d{2,}")){

            $syncHash.prevReleaseNum = $prevReleaseTextbox.Text
            $folderContents = Get-ChildItem $syncHash.prevBoipPath -Recurse | Where-Object {$_.Name.Contains($syncHash.prevReleaseNum)}
            $fileNamePaths = $folderContents| ForEach-Object -Process {$_.FullName}

            #If path exist
            if((!([string]::IsNullOrEmpty($prevChangeTextbox.Text))) -and (Test-Path $syncHash.prevBoipPath))
            {
                
                if(($fileNamePaths | Foreach { if ($_){Test-Path $_}}) -and (!([string]::IsNullOrEmpty($prevReleaseTextbox.Text)))){
                    
                    $prevReleaseTextbox.BorderBrush="#22ba00"
                    
                    $syncHash.prErrorDisplay.Text = "Release Found."
                    $syncHash.prErrorDisplay.Foreground="#22ba00"
                    $syncHash.prErrorDisplay.Visibility="Visible"

                    $Script:prValidationResult = $True
                }else{
                    $prevReleaseTextbox.BorderBrush="#ba0000"
                    
                    $syncHash.prErrorDisplay.Text = "Incorrect Format."
                    $syncHash.prErrorDisplay.Foreground="#ba0000"
                    $syncHash.prErrorDisplay.Visibility="Visible"

                    $Script:prValidationResult = $False
                }

            }elseif((!([string]::IsNullOrEmpty($prevReleaseTextbox.Text)))){
                $prevReleaseTextbox.BorderBrush="#ba0000"
                
                $syncHash.prErrorDisplay.Text = "Previous SNOW Number Required."
                $syncHash.prErrorDisplay.Foreground="#ba0000"
                $syncHash.prErrorDisplay.Visibility="Visible"

                $syncHash.TextBoxPC.BorderBrush="#ba0000"
                $syncHash.pcErrorDisplay.Text = "Field Required."
                $syncHash.pcErrorDisplay.Foreground="#ba0000"
                $syncHash.pcErrorDisplay.Visibility="Visible"

                $Script:prValidationResult = $False


            }else{
                    $prevReleaseTextbox.BorderBrush="#ba0000"
                    
                    $syncHash.prErrorDisplay.Text = "Incorrect Format."
                    $syncHash.prErrorDisplay.Foreground="#ba0000"
                    $syncHash.prErrorDisplay.Visibility="Visible"

                    $Script:prValidationResult = $False
                 }

        
        }elseif([string]::IsNullOrEmpty($prevReleaseTextbox.Text)){
            $prevReleaseTextbox.BorderBrush="#ba0000"
            
            $syncHash.prErrorDisplay.Text = "Field Required."
            $syncHash.prErrorDisplay.Foreground="#ba0000"
            $syncHash.prErrorDisplay.Visibility="Visible"

            $Script:prValidationResult = $False
        }elseif((!([string]::IsNullOrEmpty($prevReleaseTextbox.Text)))){
            $prevReleaseTextbox.BorderBrush="#ba0000"
            
            $syncHash.prErrorDisplay.Text = "Incorrect Format."
            $syncHash.prErrorDisplay.Foreground="#ba0000"
            $syncHash.prErrorDisplay.Visibility="Visible"

            $Script:prValidationResult = $False
        }
    })

    $newReleaseTextbox = $syncHash.TextBoxCR
    $newReleaseTextbox.Add_TextChanged({
        if ($newReleaseTextbox.Text -match"R\d{2,}[.]\d{1,}" -or ($newReleaseTextbox.Text -match "R\d{2,}")){

            $script:syncHash.newReleaseNum = $newReleaseTextbox.Text
            $newReleaseTextbox.BorderBrush="#22ba00"
            $syncHash.crErrorDisplay.Foreground="#22ba00"
            $syncHash.crErrorDisplay.Visibility="Hidden"

            $Script:crValidationResult = $True

        
        }elseif([string]::IsNullOrEmpty($newReleaseTextbox.Text)){
            $newReleaseTextbox.BorderBrush="#ba0000"
            
            $syncHash.crErrorDisplay.Text = "Field Required."
            $syncHash.crErrorDisplay.Foreground="#ba0000"
            $syncHash.crErrorDisplay.Visibility="Visible"

            $Script:crValidationResult = $False
        }else{
            $newReleaseTextbox.BorderBrush="#ba0000"
            
            $syncHash.crErrorDisplay.Text = "Incorrect Format."
            $syncHash.crErrorDisplay.Foreground="#ba0000"
            $syncHash.crErrorDisplay.Visibility="Visible"

            $Script:crValidationResult = $False
        }
    })

}

#region Previous Page Two
$syncHash.BtnBackPageTwo.add_Click({
    $syncHash.WizardWindowFrame.NavigationService.Navigate($syncHash.prevChangePageOne)
})

$syncHash.BtnUpdatePageTwo.Add_Click({
        if(($dpProdValidationResult -eq $True) -and ($dpQAValidationResult -eq $True) -and ($dpDevValidationResult  -eq $True)){
            #Open updatePage
            $syncHash.WizardWindowFrame.NavigationService.Navigate($syncHash.updatePage)
            
            $syncHash.WizardWindowFrame.Add_ContentRendered({
                $runspace = [runspacefactory]::CreateRunspace($initialSessionState)
                $powershell = [powershell]::Create()
                $powershell.runspace = $runspace
                $runspace.ThreadOptions = "ReuseThread"
                $runspace.ApartmentState = "STA"
                $runspace.Open()
                $runspace.SessionStateProxy.SetVariable("syncHash",$syncHash)
                
                [void]$PowerShell.AddScript({
                    param(
                        $syncHash
                    )

                    #Importing function.ps1 file into runspace
                    . $syncHash.functionPS1

                    $syncHash.WizardWindowFrame.NavigationService.Navigate($syncHash.updatePage)

                    #Call advance function to copy and modify previous boips folder & filenames
                    Create-Boip-Dir $syncHash.prevBoipPath $syncHash.currentBoipPath $syncHash.prevReleaseNum $syncHash.newReleaseNum | Out-Null
                  
            
                   $runspace = [runspacefactory]::CreateRunspace($initialSessionState)
                        $powershell = [powershell]::Create()
                        $powershell.runspace = $runspace
                        $runspace.ThreadOptions = "ReuseThread"
                        $runspace.ApartmentState = "STA"
                        $runspace.Open()
                        $runspace.SessionStateProxy.SetVariable("syncHash",$syncHash)
                
                        [void]$PowerShell.AddScript({
                            param(
                                $syncHash
                            )

                            #Importing function.ps1 file into runspace
                            . $syncHash.functionPS1

                  
                            Update-Boips $syncHash.prevBoipPath $syncHash.currentBoipPath $syncHash.prevReleaseNum $syncHash.newReleaseNum $syncHash.prodDeployDate $syncHash.qaDeployDate $syncHash.devDeployDate $syncHash.vendorUpdatesPath | Out-Null
                    
                        })

                        [void]$PowerShell.AddArgument($syncHash)
                        $AsyncObject = $PowerShell.BeginInvoke()

                    })

                    [void]$PowerShell.AddArgument($syncHash)
                    $AsyncObject = $PowerShell.BeginInvoke()
                    })
        }


        
        
        if(($dpProdValidationResult -eq $False) -and ($dpQAValidationResult -eq $False) -and ($dpDevValidationResult  -eq $False)){
            $syncHash.dPProdDate.BorderBrush="#ba0000"
        
            $syncHash.pDateErrorDisplay.Text="Field Required."
            $syncHash.pDateErrorDisplay.Foreground="#ba0000"
            $syncHash.pDateErrorDisplay.Visibility="Visible"

            $syncHash.dPQADate.BorderBrush="#ba0000"
        
            $syncHash.qDateErrorDisplay.Text="Field Required."
            $syncHash.qDateErrorDisplay.Foreground="#ba0000"
            $syncHash.qDateErrorDisplay.Visibility="Visible"

            $syncHash.dPDevDate.BorderBrush="#ba0000"
        
            $syncHash.dDateErrorDisplay.Text="Field Required."
            $syncHash.dDateErrorDisplay.Foreground="#ba0000"
            $syncHash.dDateErrorDisplay.Visibility="Visible"

        }
        
        if($dpProdValidationResult -eq $False){
               $syncHash.dPProdDate.BorderBrush="#ba0000"
        
               $syncHash.pDateErrorDisplay.Text="Field Required."
               $syncHash.pDateErrorDisplay.Foreground="#ba0000"
               $syncHash.pDateErrorDisplay.Visibility="Visible"

            }
            if($dpQAValidationResult -eq $False){
                $syncHash.dPQADate.BorderBrush="#ba0000"
        
                $syncHash.qDateErrorDisplay.Text="Field Required."
                $syncHash.qDateErrorDisplay.Foreground="#ba0000"
                $syncHash.qDateErrorDisplay.Visibility="Visible"
            }
            if($dpDevValidationResult  -eq $False){
                $syncHash.dPDevDate.BorderBrush="#ba0000"
        
                $syncHash.dDateErrorDisplay.Text="Field Required."
                $syncHash.dDateErrorDisplay.Foreground="#ba0000"
                $syncHash.dDateErrorDisplay.Visibility="Visible"
            }
 
    
})


$dpProdValidationResult = $False
$dpQAValidationResult = $False
$dpDevValidationResult = $False

if($syncHash.prevChangePageTwo.IsInitialized){
    
    $syncHash.dPDevDate.Add_SelectedDateChanged({
        $syncHash.devDeployDate = $syncHash.dPDevDate.SelectedDate

        if(($syncHash.devDeployDate -match "\d{2}[/]\d{1,2}[/]\d{4}") -and (!([string]::IsNullOrEmpty($syncHash.devDeployDate)))){
            
            Format-Date -deployDate ([ref]$syncHash.devDeployDate)
            $syncHash.dPDevDate.BorderBrush="#22ba00"
            
            $syncHash.dDateErrorDisplay.Text="Valid Date."
            $syncHash.dDateErrorDisplay.Foreground="#22ba00"
            $syncHash.dDateErrorDisplay.Visibility="Visible"

            
            $Script:dpDevValidationResult = $True
        
            }else{
                $syncHash.dPDevDate.BorderBrush="#ba0000"

                $syncHash.dDateErrorDisplay.Text="Field Required."
                $syncHash.dDateErrorDisplay.Foreground="#ba0000"
                $syncHash.dDateErrorDisplay.Visibility="Visible"
            }
         })
    
    $syncHash.dPQADate.Add_SelectedDateChanged({
        $syncHash.qaDeployDate = $syncHash.dPQADate.SelectedDate

        if(($syncHash.qaDeployDate -match "\d{2}[/]\d{1,2}[/]\d{4}") -and (!([string]::IsNullOrEmpty($syncHash.qaDeployDate)))){
            
            Format-Date -deployDate ([ref]$syncHash.qaDeployDate)
            $syncHash.dPQADate.BorderBrush="#22ba00"
            
            $syncHash.qDateErrorDisplay.Text="Valid Date."
            $syncHash.qDateErrorDisplay.Foreground="#22ba00"
            $syncHash.qDateErrorDisplay.Visibility="Visible"

            $Script:dpQAValidationResult = $True
        
            }else{
                $syncHash.dPQADate.BorderBrush="#ba0000"

                $syncHash.qDateErrorDisplay.Text="Field Required."
                $syncHash.qDateErrorDisplay.Foreground="#ba0000"
                $syncHash.qDateErrorDisplay.Visibility="Visible"
            }

    })

    $syncHash.dPProdDate.Add_SelectedDateChanged({
        $syncHash.prodDeployDate = $syncHash.dPProdDate.SelectedDate

        if(($syncHash.prodDeployDate -match "\d{2}[/]\d{1,2}[/]\d{4}") -and (!([string]::IsNullOrEmpty($syncHash.prodDeployDate)))){
            
            Format-Date -deployDate ([ref]$syncHash.prodDeployDate)
            $syncHash.dPProdDate.BorderBrush="#22ba00"
            
            $syncHash.pDateErrorDisplay.Text="Valid Date."
            $syncHash.pDateErrorDisplay.Foreground="#22ba00"
            $syncHash.pDateErrorDisplay.Visibility="Visible"

            $Script:dpProdValidationResult = $True
        
            }else{
                $syncHash.dPProdDate.BorderBrush="#ba0000"

                $syncHash.pDateErrorDisplay.Text="Field Required."
                $syncHash.pDateErrorDisplay.Foreground="#ba0000"
                $syncHash.pDateErrorDisplay.Visibility="Visible"
            }

    })
    
}
        
#region Gui Logic
$syncHash.WizardWindowFrame.NavigationService.Navigate($syncHash.launchPage)
$script:syncHash.WizardWindow.ShowDialog() | Out-Null
})
[void]$PowerShell.AddArgument($syncHash)


$AsyncObject = $PowerShell.BeginInvoke()

#Get-Runspace | Where-Object {$_.RunspaceAvailability -eq 'Available'} | ForEach-Object {$_.Dispose()}
#Get-runspace | Where-Object {$_.Debugger.InBreakpoint -eq $true} | Debug-Runspace