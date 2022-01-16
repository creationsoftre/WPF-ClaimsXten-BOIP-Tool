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
$syncHash.vendorUpdatesPath = "\\<fqdnservername>\apps\Local\EMT\COTS\McKesson\ClaimsXten\v6.3\McKesson-supplied-updates"
$syncHash.excelPath = Join-Path -Path $PWD.Path -ChildPath "\Utils\templatedata.xlsx"

$syncHash.message


#######################################
#Import External Functions and Methods#
#######################################
$syncHash.functionPS1 = Join-Path -Path $PWD.Path -ChildPath "\Functions.ps1"
. $syncHash.functionPS1

if (Get-Module -ListAvailable -Name PSExcel) {
    Write-Host "Module exists"
    Import-Module PSexcel
} 
else {
    Write-Host "Module does not exist"
    Install-module PSExcel
}

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
    

    #region: Previous Change
    $syncHash.BtnPreviousChange.add_Click({
        $syncHash.WizardWindowFrame.NavigationService.Navigate($syncHash.prevChangePageOne)
    })


$syncHash.BtnNextPageOne.add_Click({
        
        if(($pcValidationResult -eq $True) -and ($ccValidationResult -eq $True) -and ($prValidationResult -eq $True) -and ($crValidationResult -eq $True)){
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
        if($crValidationResult -eq $False){
            $newReleaseTextbox.BorderBrush="#ba0000"
        
            $syncHash.crErrorDisplay.Text = "Field Required."
            $syncHash.crErrorDisplay.Foreground="#ba0000"
            $syncHash.crErrorDisplay.Visibility="Visible"
        }
    
})

#region Previous Page One
$syncHash.BtnBackPageOne.add_Click({
    $syncHash.WizardWindowFrame.GoBack()

    #Clear Textboxes
    $textBoxes = $syncHash.TextBoxPC, $syncHash.TextBoxCC, $syncHash.TextBoxPR, $syncHash.TextBoxCR
    foreach($textBox in $textBoxes){
        $textBox.Clear()
        $textBox.BorderBrush="#FFFFD960"
    }

    #Set Gui display back to original state
    $errorDisplays = $syncHash.pcErrorDisplay, $syncHash.ccErrorDisplay, $syncHash.prErrorDisplay, $syncHash.crErrorDisplay
    foreach($errorDisplay in $errorDisplays){
        #$errorDisplay.clear()
        $errorDisplay.Visibility="Hidden"
    }
    
})

$pcValidationResult = $False
$ccValidationResult = $False
$prValidationResult = $False
$crValidationResult = $False

if($syncHash.prevChangePageOne.IsInitialized){
    $script:prevChangeTextbox = $syncHash.TextBoxPC
        $prevChangeTextbox.Add_TextChanged({
            if (($prevChangeTextbox.Text -match '[A-Za-z]{4}[-]\w{4,}') -and (!([string]::IsNullOrEmpty($prevChangeTextbox.Text)))){
                $syncHash.prevCNR = $prevChangeTextbox.Text

                #Gets previous CNR from BoipPath defined above
                $syncHash.prevBoipPath = Join-Path -Path $syncHash.boipPath -ChildPath $syncHash.prevCNR

                if(Test-Path $syncHash.prevBoipPath)
                {
                    $prevChangeTextbox.BorderBrush="#22ba00"
            
                    $syncHash.pcErrorDisplay.Text = "SNOW Path Found."
                    $syncHash.pcErrorDisplay.Foreground="#22ba00"
                    $syncHash.pcErrorDisplay.Visibility="Visible"

                    $Script:pcValidationResult = $True

                    if((!([string]::IsNullOrEmpty($prevReleaseTextbox.Text)))){
                        if ($prevReleaseTextbox.Text -match"R\d{2,}[.]\d{1,}" -or ($prevReleaseTextbox.Text -match "R\d{2,}")){
                            $folderContents = Get-ChildItem $syncHash.prevBoipPath -Recurse | Where-Object {$_.Name.Contains($syncHash.prevReleaseNum)}
                            $fileNamePaths = $folderContents| ForEach-Object -Process {$_.FullName}

                            if(($fileNamePaths | Foreach { if ($_){Test-Path $_}}) -and (!([string]::IsNullOrEmpty($prevReleaseTextbox.Text)))){
                    
                                $prevReleaseTextbox.BorderBrush="#22ba00"
                    
                                $syncHash.prErrorDisplay.Text = "Release Found."
                                $syncHash.prErrorDisplay.Foreground="#22ba00"
                                $syncHash.prErrorDisplay.Visibility="Visible"

                                $Script:prValidationResult = $True
                            }else{
                                $prevReleaseTextbox.BorderBrush="#ba0000"
                    
                                $syncHash.prErrorDisplay.Text = "Release not found."
                                $syncHash.prErrorDisplay.Foreground="#ba0000"
                                $syncHash.prErrorDisplay.Visibility="Visible"

                                $Script:prValidationResult = $False
                            }
                        }else{
                                $prevReleaseTextbox.BorderBrush="#ba0000"
                    
                                $syncHash.prErrorDisplay.Text = "Incorrect format."
                                $syncHash.prErrorDisplay.Foreground="#ba0000"
                                $syncHash.prErrorDisplay.Visibility="Visible"

                                $Script:prValidationResult = $False
                            }
                    }
            
                }else{
            
                    $prevChangeTextbox.BorderBrush="#ba0000"
            
                    $syncHash.pcErrorDisplay.Text = "SNOW Path Was Not Found."
                    $syncHash.pcErrorDisplay.Foreground="#ba0000"
                    $syncHash.pcErrorDisplay.Visibility="Visible"

                    $Script:pcValidationResult = $False

                }

        
            }elseif(([string]::IsNullOrEmpty($prevChangeTextbox.Text))){
                $script:prevChangeTextbox.BorderBrush="#ba0000"
        
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

        $script:currentChangeTextbox = $syncHash.TextBoxCC
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
    
        $script:prevReleaseTextbox = $syncHash.TextBoxPR
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

        $script:newReleaseTextbox = $syncHash.TextBoxCR
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
                #Add Function to session state
                $AsyncObject = @()

                $SessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
                $SessionState.ApartmentState = 'STA'
                $SessionState.ThreadOptions = 'ReuseThread'
                $Runspace = [runspacefactory]::CreateRunspace($SessionState)
                $Runspace.Open()
                $Runspace.SessionStateProxy.SetVariable("syncHash",$syncHash)
                

                #Create a PowerShell command to run in the pool
                $PowerShell = [System.Management.Automation.PowerShell]::Create()
                $PowerShell.Runspace = $Runspace
                $PowerShell.AddScript({
                    param(
                        $syncHash
                    )
                    #Importing function.ps1 file into runspace
                    . $syncHash.functionPS1

                    $synchash.DeterminateCircularProgress.Dispatcher.Invoke({
                        $syncHash.DeterminateCircularProgress.IsIndeterminate = $true
                    })
                }).AddArgument($syncHash)
                $AsyncObject = $PowerShell.BeginInvoke()

                $PowerShell = [System.Management.Automation.PowerShell]::Create()
                $PowerShell.RunspacePool = $RunspacePool
                $PowerShell.AddScript({
                    param(
                        $syncHash
                    )
                    #Importing function.ps1 file into runspace
                    . $syncHash.functionPS1

                    Create-Boip-Dir $syncHash.prevBoipPath $syncHash.currentBoipPath $syncHash.prevReleaseNum $syncHash.newReleaseNum

                    $boipUpdateStatus = Update-Boips $syncHash.prevBoipPath $syncHash.currentBoipPath $syncHash.prevReleaseNum $syncHash.newReleaseNum $syncHash.prodDeployDate $syncHash.qaDeployDate $syncHash.devDeployDate $syncHash.vendorUpdatesPath

                    if($boipUpdateStatus -eq "Done"){
                        $synchash.DeterminateCircularProgress.Dispatcher.Invoke({
                            $syncHash.DeterminateCircularProgress.IsIndeterminate = $false
                            $syncHash.DeterminateCircularProgress.Foreground = "#22ba00"
                            $syncHash.DeterminateCircularProgress.Value = "100"
                            $syncHash.Check.Visibility = "Visible"

                            $syncHash.BtnMenu.IsEnabled = "True"
                            $syncHash.BtnContinue.IsEnabled = "True"
                        })
                    }
                }).AddArgument($syncHash)
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

$syncHash.BtnMenu.Add_Click({
    $syncHash.WizardWindowFrame.NavigationService.Navigate($syncHash.launchPage)

     #Clear Textboxes
    $textBoxes = $syncHash.TextBoxPC, $syncHash.TextBoxCC, $syncHash.TextBoxPR, $syncHash.TextBoxCR
    foreach($textBox in $textBoxes){
        $textBox.Clear()
        $textBox.BorderBrush="#FFFFD960"
    }

    #Set Gui display back to original state
    $errorDisplays = $syncHash.pcErrorDisplay, $syncHash.ccErrorDisplay, $syncHash.prErrorDisplay, $syncHash.crErrorDisplay
    foreach($errorDisplay in $errorDisplays){
        $errorDisplay.clear()
        $errorDisplay.Visibility="Hidden"
    }
})

$syncHash.BtnContinue.Add_Click({
    $syncHash.WizardWindow.Close() | Out-Null
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


######################################Region: Template###################################################
$syncHash.btnTemplate.Add_Click({
    $syncHash.WizardWindowFrame.NavigationService.Navigate($syncHash.templateMenuPage)
})

$syncHash.BtnBackTempMenu.Add_Click({
    $syncHash.WizardWindowFrame.NavigationService.Navigate($syncHash.launchPage)
})

if($syncHash.templateMenuPage.IsInitialized){


    #Pull template menu data from excel spreadsheet
    $syncHash.menuDataContent = new-object System.Collections.ArrayList


    #Test if file is open as menu will not load if so.
    foreach ($dataContents in (Import-XLSX -Path $syncHash.excelPath -RowStart 1 | Where-Object { ($_.PSObject.Properties | ForEach-Object {$_.Value}) -ne $null}))
    {
        if($dataContents -ne $null){
            $syncHash.menuDataContent.add($dataContents) | out-null
        }
    }

    #Update Template Menu With Name and Description from .xls
    $syncHash.menuListBox.ItemsSource = $syncHash.menuDataContent

    $syncHash.menuListBox.add_SelectionChanged({
        if($syncHash.menuListBox.SelectedIndex -lt $syncHash.menuListBox.Items.Count){
            $selectedItemName = $syncHash.menuListBox.SelectedValue.'Template Type'
            $selectedItemFolder = $syncHash.menuListBox.SelectedValue.Folder

            $syncHash.tempBoipPath = Join-Path -Path $syncHash.tempBoipPath -ChildPath $selectedItemFolder
            if(TEST-Path $syncHash.tempBoipPath){
                $wpf.BtnNexttemplateMenu.IsEnabled = $true
                $syncHash.BtnNexttemplateMenu.Add_Click({
                    $syncHash.WizardWindowFrame.NavigationService.Navigate($syncHash.tempUpdatePageOne)
                })
            }else{
                #show dialog stating path was not found
                
            }
        }

     })
    
}

$pTcValidationResult = $False
$cTcValidationResult = $False
$pTrValidationResult = $False
$cTrValidationResult = $False

if($syncHash.tempUpdatePageOne.IsInitialized){
        $syncHash.prevTempReleaseNum = "R#"
        $syncHash.prevTempChangeTextbox = "SNOW-TEMP"

        $script:currentTempChangeTextbox = $syncHash.TextBoxCTC
        $currentTempChangeTextbox.Add_TextChanged({
                if (($currentTempChangeTextbox.Text -match '[A-Za-z]{4}[-]\w{4,}') -and ($currentTempChangeTextbox.Text -ne $prevTempChangeTextbox.Text)) {
            
                    $syncHash.newCNR = $currentTempChangeTextbox.Text
                    $syncHash.currentBoipPath = Join-Path -Path $syncHash.boipPath -ChildPath $syncHash.newCNR

                    if(Test-Path $syncHash.currentBoipPath){
                        $currentTempChangeTextbox.BorderBrush="#ba0000"
        
                        $syncHash.cTcErrorDisplay.Text = $syncHash.newCNR + " already exist. Please try a new change number."
                        $syncHash.cTcErrorDisplay.Foreground="#ba0000"
                        $syncHash.cTcErrorDisplay.Visibility="Visible"

                        $Script:cTcValidationResult = $False
                    }else{
                        $currentTempChangeTextbox.BorderBrush="#22ba00"

                        $syncHash.cTcErrorDisplay.Text = "SNOW Path Found."
                        $syncHash.cTcErrorDisplay.Foreground="#22ba00"
                        $syncHash.cTcErrorDisplay.Visibility="Hidden"

                        $Script:cTcValidationResult = $True
                    }    

        
                }elseif([string]::IsNullOrEmpty($currentTempChangeTextbox.Text)){
                    $currentTempChangeTextbox.BorderBrush="#ba0000"
        
                    $syncHash.cTcErrorDisplay.Text = "Field Required."
                    $syncHash.cTcErrorDisplay.Foreground="#ba0000"
                    $syncHash.cTcErrorDisplay.Visibility="Visible"

                    $Script:cTcValidationResult = $False
                }elseif($currentTempChangeTextbox.Text -match $prevTempChangeTextbox.Text){
                    $currentTempChangeTextbox.BorderBrush="#ba0000"
        
                    $syncHash.cTcErrorDisplay.Text = "Current and Previous Change Request Cannot Match."
                    $syncHash.cTcErrorDisplay.Foreground="#ba0000"
                    $syncHash.cTcErrorDisplay.Visibility="Visible"

                    $Script:cTcValidationResult = $False
        
                }else{
                    $currentTempChangeTextbox.BorderBrush="#ba0000"
        
                    $syncHash.cTcErrorDisplay.Text = "Incorrect Format."
                    $syncHash.cTcErrorDisplay.Foreground="#ba0000"
                    $syncHash.cTcErrorDisplay.Visibility="Visible"

                    $Script:cTcValidationResult = $False

                }
            })
    

        $script:newTempReleaseTextbox = $syncHash.TextBoxCTR
        $newTempReleaseTextbox.Add_TextChanged({
                if ($newTempReleaseTextbox.Text -match"R\d{2,}[.]\d{1,}" -or ($newTempReleaseTextbox.Text -match "R\d{2,}")){

                    $script:syncHash.newTempReleaseNum = $newTempReleaseTextbox.Text
                    $newTempReleaseTextbox.BorderBrush="#22ba00"
                    $syncHash.cTrErrorDisplay.Foreground="#22ba00"
                    $syncHash.cTrErrorDisplay.Visibility="Hidden"

                    $Script:cTrValidationResult = $True

        
                }elseif([string]::IsNullOrEmpty($newTempReleaseTextbox.Text)){
                    $newTempReleaseTextbox.BorderBrush="#ba0000"
            
                    $syncHash.cTrErrorDisplay.Text = "Field Required."
                    $syncHash.cTrErrorDisplay.Foreground="#ba0000"
                    $syncHash.cTrErrorDisplay.Visibility="Visible"

                    $Script:cTrValidationResult = $False
                }else{
                    $newTempReleaseTextbox.BorderBrush="#ba0000"
            
                    $syncHash.cTrErrorDisplay.Text = "Incorrect Format."
                    $syncHash.cTrErrorDisplay.Foreground="#ba0000"
                    $syncHash.cTrErrorDisplay.Visibility="Visible"

                    $Script:cTrValidationResult = $False
                }
            })
}

$syncHash.BtnBackTempPageOne.Add_Click({
    $syncHash.WizardWindowFrame.NavigationService.Navigate($syncHash.launchPage)
})

$syncHash.BtnNextTempPageOne.add_Click({
        
        if(($cTcValidationResult -eq $True) -and ($cTrValidationResult -eq $True)){
             $syncHash.WizardWindowFrame.NavigationService.Navigate($syncHash.TempDateUpdatePage)
        }
    
        if($cTcValidationResult -eq $False){
            $currentTempChangeTextbox.BorderBrush="#ba0000"
        
            $syncHash.cTcErrorDisplay.Text = "Field Required."
            $syncHash.cTcErrorDisplay.Foreground="#ba0000"
            $syncHash.cTcErrorDisplay.Visibility="Visible"
        }
        
        if($cTrValidationResult -eq $False){
            $newTempReleaseTextbox.BorderBrush="#ba0000"
        
            $syncHash.cTrErrorDisplay.Text = "Field Required."
            $syncHash.cTrErrorDisplay.Foreground="#ba0000"
            $syncHash.cTrErrorDisplay.Visibility="Visible"
        }
    
})

$tdpProdValidationResult = $False
$tdpQAValidationResult = $False
$tdpDevValidationResult = $False

if($syncHash.TempDateUpdatePage.IsInitialized){
    
    $syncHash.tempDPDevDate.Add_SelectedDateChanged({
        $syncHash.tempDevDeployDate = $syncHash.tempDPDevDate.SelectedDate

        if(($syncHash.tempDevDeployDate -match "\d{2}[/]\d{1,2}[/]\d{4}") -and (!([string]::IsNullOrEmpty($syncHash.tempDevDeployDate)))){
            
            Format-Date -deployDate ([ref]$syncHash.tempDevDeployDate)
            $syncHash.tempDPDevDate.BorderBrush="#22ba00"
            
            $syncHash.tempDDateErrorDisplay.Text="Valid Date."
            $syncHash.tempDDateErrorDisplay.Foreground="#22ba00"
            $syncHash.tempDDateErrorDisplay.Visibility="Visible"

            
            $Script:tdpDevValidationResult = $True
        
            }else{
                $syncHash.tempDPDevDate.BorderBrush="#ba0000"

                $syncHash.tempDDateErrorDisplay.Text="Field Required."
                $syncHash.tempDDateErrorDisplay.Foreground="#ba0000"
                $syncHash.tempDDateErrorDisplay.Visibility="Visible"
            }
         })
    
    $syncHash.tempDPQADate.Add_SelectedDateChanged({
        $syncHash.tempQADeployDate = $syncHash.tempDPQADate.SelectedDate

        if(($syncHash.tempQADeployDate -match "\d{2}[/]\d{1,2}[/]\d{4}") -and (!([string]::IsNullOrEmpty($syncHash.tempQADeployDate)))){
            
            Format-Date -deployDate ([ref]$syncHash.tempQADeployDate)
            $syncHash.tempDPQADate.BorderBrush="#22ba00"
            
            $syncHash.tempQDateErrorDisplay.Text="Valid Date."
            $syncHash.tempQDateErrorDisplay.Foreground="#22ba00"
            $syncHash.tempQDateErrorDisplay.Visibility="Visible"

            $Script:tdpQAValidationResult = $True
        
            }else{
                $syncHash.tempDPQADate.BorderBrush="#ba0000"

                $syncHash.tempQDateErrorDisplay.Text="Field Required."
                $syncHash.tempQDateErrorDisplay.Foreground="#ba0000"
                $syncHash.tempQDateErrorDisplay.Visibility="Visible"
            }

    })

    $syncHash.tempDPProdDate.Add_SelectedDateChanged({
        $syncHash.tempProdDeployDate = $syncHash.tempDPProdDate.SelectedDate

        if(($syncHash.tempProdDeployDate -match "\d{2}[/]\d{1,2}[/]\d{4}") -and (!([string]::IsNullOrEmpty($syncHash.tempProdDeployDate)))){
            
            Format-Date -deployDate ([ref]$syncHash.tempProdDeployDate)
            $syncHash.tempDPProdDate.BorderBrush="#22ba00"
            
            $syncHash.tempPDateErrorDisplay.Text="Valid Date."
            $syncHash.tempPDateErrorDisplay.Foreground="#22ba00"
            $syncHash.tempPDateErrorDisplay.Visibility="Visible"

            $Script:tdpProdValidationResult = $True
        
            }else{
                $syncHash.tempDPProdDate.BorderBrush="#ba0000"

                $syncHash.tempPDateErrorDisplay.Text="Field Required."
                $syncHash.tempPDateErrorDisplay.Foreground="#ba0000"
                $syncHash.tempPDateErrorDisplay.Visibility="Visible"
            }

    })
    
}


$syncHash.BtnUpdateTempUpdatePage.Add_Click({
        if(($tdpProdValidationResult -eq $True) -and ($tdpQAValidationResult -eq $True) -and ($tdpDevValidationResult  -eq $True)){
            #Open updatePage
            $syncHash.WizardWindowFrame.NavigationService.Navigate($syncHash.updatePage)
            
            $syncHash.WizardWindowFrame.Add_ContentRendered({
                #Add Function to session state
                $AsyncObject = @()

                $SessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
                $SessionState.ApartmentState = 'STA'
                $SessionState.ThreadOptions = 'ReuseThread'
                $Runspace = [runspacefactory]::CreateRunspace($SessionState)
                $Runspace.Open()
                $Runspace.SessionStateProxy.SetVariable("syncHash",$syncHash)

                #Create a PowerShell command to run in the pool
                $PowerShell = [System.Management.Automation.PowerShell]::Create()
                $PowerShell.Runspace = $Runspace
                $PowerShell.AddScript({
                    param(
                        $syncHash
                    )
                    #Importing function.ps1 file into runspace
                    . $syncHash.functionPS1

                    $synchash.DeterminateCircularProgress.Dispatcher.Invoke({
                        $syncHash.DeterminateCircularProgress.IsIndeterminate = $true
                    })
                }).AddArgument($syncHash)
                $AsyncObject = $PowerShell.BeginInvoke()

                $PowerShell = [System.Management.Automation.PowerShell]::Create()
                $PowerShell.RunspacePool = $RunspacePool
                $PowerShell.AddScript({
                    param(
                        $syncHash
                    )
                    #Importing function.ps1 file into runspace
                    . $syncHash.functionPS1


                    Create-Boip-Dir $syncHash.tempBoipPath $syncHash.currentBoipPath $syncHash.prevTempReleaseNum $syncHash.newTempReleaseNum

                    $tempBoipUpdateStatus = Temp-Boip-Updates $syncHash.tempBoipPath $syncHash.currentBoipPath $syncHash.prevTempReleaseNum $syncHash.newTempReleaseNum $syncHash.tempProdDeployDate $syncHash.tempQADeployDate $syncHash.tempDevDeployDate $syncHash.vendorUpdatesPath

                    if($tempBoipUpdateStatus -eq "Done"){
                        $synchash.DeterminateCircularProgress.Dispatcher.Invoke({
                            $syncHash.DeterminateCircularProgress.IsIndeterminate = $false
                            $syncHash.DeterminateCircularProgress.Foreground = "#22ba00"
                            $syncHash.DeterminateCircularProgress.Value = "100"
                            $syncHash.Check.Visibility = "Visible"

                            $syncHash.BtnMenu.IsEnabled = "True"
                            $syncHash.BtnContinue.IsEnabled = "True"
                        })
                    }
                }).AddArgument($syncHash)
                $AsyncObject = $PowerShell.BeginInvoke()
             })
        }
        
        
        if(($tdpProdValidationResult -eq $False) -and ($tdpQAValidationResult -eq $False) -and ($tdpDevValidationResult  -eq $False)){
            $syncHash.dPProdDate.BorderBrush="#ba0000"
        
            $syncHash.tempPDateErrorDisplay.Text="Field Required."
            $syncHash.tempPDateErrorDisplay.Foreground="#ba0000"
            $syncHash.tempPDateErrorDisplay.Visibility="Visible"

            $syncHash.tempDPQADate.BorderBrush="#ba0000"
        
            $syncHash.tempQDateErrorDisplay.Text="Field Required."
            $syncHash.tempQDateErrorDisplay.Foreground="#ba0000"
            $syncHash.tempQDateErrorDisplay.Visibility="Visible"

            $syncHash.dPDevDate.BorderBrush="#ba0000"
        
            $syncHash.tempDDateErrorDisplay.Text="Field Required."
            $syncHash.tempDDateErrorDisplay.Foreground="#ba0000"
            $syncHash.tempDDateErrorDisplay.Visibility="Visible"

        }
        
        if($tdpProdValidationResult -eq $False){
               $syncHash.tempDPProdDate.BorderBrush="#ba0000"
        
               $syncHash.tempPDateErrorDisplay.Text="Field Required."
               $syncHash.tempPDateErrorDisplay.Foreground="#ba0000"
               $syncHash.tempPDateErrorDisplay.Visibility="Visible"

            }
            if($tdpQAValidationResult -eq $False){
                $syncHash.tempQPQADate.BorderBrush="#ba0000"
        
                $syncHash.tempQDateErrorDisplay.Text="Field Required."
                $syncHash.tempQDateErrorDisplay.Foreground="#ba0000"
                $syncHash.tempQDateErrorDisplay.Visibility="Visible"
            }
            if($tdpDevValidationResult  -eq $False){
                $syncHash.tempDPDevDate.BorderBrush="#ba0000"
        
                $syncHash.tempDDateErrorDisplay.Text="Field Required."
                $syncHash.tempDDateErrorDisplay.Foreground="#ba0000"
                $syncHash.tempDDateErrorDisplay.Visibility="Visible"
            }
})


#Launch GUI
$syncHash.WizardWindowFrame.NavigationService.Navigate($syncHash.launchPage)
$script:syncHash.WizardWindow.ShowDialog() | Out-Null
})
[void]$PowerShell.AddArgument($syncHash)

Runspace-Cleanup

$AsyncObject = $PowerShell.BeginInvoke()

#Get-Runspace | Where-Object {$_.RunspaceAvailability -eq 'Available'} | ForEach-Object {$_.Dispose()}
#Get-runspace | Where-Object {$_.Debugger.InBreakpoint -eq $true} | Debug-Runspace