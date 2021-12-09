#################
#   Functions   #
#################



function Get-XamlObject
{
	[CmdletBinding()]
	param (
		[Parameter(Position = 0,
				   Mandatory = $true,
				   ValuefromPipelineByPropertyName = $true,
				   ValuefromPipeline = $true)]
		[Alias("FullName")]
		[System.String[]]$Path
	)

	BEGIN
	{
		Set-StrictMode -Version Latest

		$wpfObjects = @{ }
		[System.Reflection.Assembly]::LoadFrom("$PWD/assembly/MaterialDesignThemes.Wpf.dll") | Out-Null
        [System.Reflection.Assembly]::LoadFrom("$PWD/assembly/MaterialDesignColors.dll") | Out-Null

	} #BEGIN

	PROCESS
	{
		try
		{
			foreach ($xamlFile in $Path)
			{
				#Change content of Xaml file to be a set of powershell GUI objects
				$inputXML = Get-Content -Path $xamlFile -ErrorAction Stop
				$inputXMLClean = $inputXML -replace 'mc:Ignorable="d"', '' -replace "x:N", 'N' -replace 'x:Class=".*?"', '' -replace 'd:DesignHeight="\d*?"', '' -replace 'd:DesignWidth="\d*?"', ''
				[xml]$xaml = $inputXMLClean
				$reader = New-Object System.Xml.XmlNodeReader $xaml -ErrorAction Stop
				$tempform = [Windows.Markup.XamlReader]::Load($reader)

				#Grab named objects from tree and put in a flat structure
				$namedNodes = $xaml.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]")
				$namedNodes | ForEach-Object {

				$wpfObjects.Add($_.Name, $tempform.FindName($_.Name))

				} #foreach-object
			} #foreach xamlpath
		} #try
		catch
		{
			throw $error[0].Exception.InnerException
            throw $error[0].Exception.StackTrace
		} #catch
	} #PROCESS

	END
	{
		Write-Output $wpfObjects
	} #END
}

Function Format-Date ([ref]$deployDate)
{
    $dateStr = $deployDate.Value -replace '\s.+$'

    #regex wildcard to determine date format (mm/dd/yyyy)
    If($dateStr -match "\d{2}[/]\d{1,2}[/]\d{4}")
    {
        #Parse date that is in format (MM/dd/yyyy) to (M/dd/yy)
        $dateStr = [datetime]::ParseExact($dateStr.Trim(), "MM/d/yyyy", $null).ToString("M/dd/yy")
            
    }

    #Determine Day of Week from New Deployment Date | Abbreviate dow | concat abbrv dow to deployment date
    $dayOfWeek = (Get-Date $dateStr ).DayOfWeek
    $abbr = (Get-Culture).DateTimeFormat.GetAbbreviatedDayName($dayOfWeek)
    $dateStr = -join $abbr.ToString() + ' ' + $dateStr
}

Function Create-Boip-Dir{
[CmdletBinding()]
	param(
		[Parameter(Position = 0,
				   Mandatory = $true,
				   ValuefromPipelineByPropertyName = $true,
				   ValuefromPipeline = $true)]
		[system.object] $prevBoipPath,

        [Parameter(Position = 1,
				   Mandatory = $true,
				   ValuefromPipelineByPropertyName = $true,
				   ValuefromPipeline = $true)]
		[system.object] $currentBoipPath,
        
        [Parameter(Position = 2,
				   Mandatory = $true,
				   ValuefromPipelineByPropertyName = $true,
				   ValuefromPipeline = $true)]
		[system.object] $prevReleaseNum,

        [Parameter(Position = 3,
				   Mandatory = $true,
				   ValuefromPipelineByPropertyName = $true,
				   ValuefromPipeline = $true)]
		[system.object] $newReleaseNum
        

        
	)
        
        $prevBoipName = Split-Path (Split-Path $prevBoipPath -leaf ) -Leaf
        $currentBoipName = Split-Path (Split-Path $currentBoipPath -leaf ) -Leaf

        $syncHash.message = "Info: Copying $prevBoipName files to $currentBoipName."
        Message-log($syncHash.message)

        Copy-Item $prevBoipPath -Destination $currentBoipPath -Recurse

        If(Test-Path $currentBoipPath -PathType leaf)
        {
            $syncHash.message = "Update: $currentBoipName files have been successfully copied."
            Message-log($syncHash.message)

            $syncHash.message = "Info: Renaming $currentBoipName Microsoft Word Documents..."
            Message-log($syncHash.message)

            Get-ChildItem $currentBoipPath -Filter *$prevReleaseNum* -Recurse | Rename-Item -NewName {$_.name -replace $prevReleaseNum, $newReleaseNum}

            
            $syncHash.message = "Update: $currentBoipName Microsoft Word Documents have been successfully renamed."
            Message-log($syncHash.message)

        }else{
            $syncHash.message = "Warning: $currentBoipName could not be found. Exiting application."
            Message-log($syncHash.message)
            Exit
        }
        
    
}

Function Determine-Boip-Content{
[CmdletBinding()]
	param(
		[Parameter()]
		[string] $prevDeployDate
        
	)

    $syncHash.message = "Info: Determining the Exsiting Deployment Date for $boipName..."
    Message-log($syncHash.message)

     $range.Text -match '([A-Za-z]{3}\s\d{1,2}[/]\d{1,2}[/]\d{2,4})'
         try 
         {
	        $prevDeployDate = $matches[1]
            $syncHash.message = "Update: $boipName Existing Deployment Date is was found. Ready to be updated."
            Message-log($syncHash.message)
         }
         catch
         {
            $syncHash.message = "Warning: $boipName Existing Deployment Date is Incorrect or Could Not Be Found."
            Message-log($syncHash.message)
            
         }

         $syncHash.message = "Info: Updating $boipName Deployment Date..."
         Message-log($syncHash.message)
         


         $a = $objSelection.Find.Execute($prevDeployDate,$MatchCase,$MatchWholeWord,$MatchWildcards,$MatchSoundsLike,$MatchAllWordForms,$Forward,$Wrap,$Format,$newQADeployDate,$wdReplaceAll)

         If($a -eq 'true')
         {
            $syncHash.message = "Update: $boipName Deployment Date Successfully Updated."
            Message-log($syncHash.message)
            
         } ELSE {
            $syncHash.message = "Warning: $boipName Deployment Date was not Successfully Updated. Skipping..."
            Message-log($syncHash.message)
            
         }
         
}

Function Update-Boips ()
{
    
    [CmdletBinding()]
	param(
		[Parameter(Position = 0,
				   Mandatory = $true,
				   ValuefromPipeline = $true)]
		[system.object] $prevBoipPath,

        [Parameter(Position = 1,
				   Mandatory = $true,
				   ValuefromPipeline = $true)]
		[system.object] $currentBoipPath,
        
        [Parameter(Position = 2,
				   Mandatory = $true,
				   ValuefromPipeline = $true)]
		[string] $prevReleaseNum,
        
        [Parameter(Position = 3,
				   Mandatory = $true,
				   ValuefromPipeline = $true)]
		[string] $newReleaseNum,

        [Parameter(Position = 4,
				   Mandatory = $true,
				   ValuefromPipeline = $true)]
		[string] $prodDeployDate,

        [Parameter(Position = 5,
				   Mandatory = $true,
				   ValuefromPipeline = $true)]
		[string] $qaDeployDate,
        
        [Parameter(Position = 6,
				   Mandatory = $true,
				   ValuefromPipeline = $true)]
		[string] $devDeployDate,

        [Parameter(Position = 7,
                  Mandatory = $true,
                  ValuefromPipeline = $true)]
        [system.object] $vendorUpdatesPath
        
	)

    #################
    #SYSTEM VARIABLES
    #################
    $MatchCase = $False 
    $MatchWholeWord = $True
    $MatchWildcards = $False 
    $MatchSoundsLike = $False 
    $MatchAllWordForms = $False 
    $Forward = $False
    $Wrap = 1
    $Format = $True
    $wdReplaceAll = 2
    
    #Variables
    $success = 0
    $skipped = 0
    $failed = 0
    
    
    ##################
    #Update PROD BOIP#
    ##################

        #BOIPS listed in array are deployed on the same day as Prod
        $prodBOIPS = Get-ChildItem $currentBoipPath -Recurse -Include ("BOIP_PROD*.docx","BOIP_DR*.docx","BOIP_BACKFLUSH*.docx") | ForEach-Object -Process {$_.FullName}

        Foreach($boip in $prodBOIPS)
        {
            
            #Check if BOIP file path exist
            if(Test-Path $boip -PathType Leaf)
            {

                #Open the PROD BOIP
                $objWord = New-Object -comobject Word.Application  
                $objWord.Visible = $False  
                $objDoc = $objWord.Documents.Open($boip)
                $range = $objDoc.content
                $boipName = [System.IO.Path]::GetFileNameWithoutExtension($boip)

                #Variable for current selection in MS Word
                $objSelection = $objWord.Selection

                #Display Boip name in GUI
                $syncHash.docNameDisplay.Dispatcher.Invoke("Normal",[action]{
                    $syncHash.docNameDisplay.Text = $boipName
                })

                
                Determine-Boip-Content


                #If New Deployment Date Contains "Sun' for Sunday. Update Start time & Date
                If($newProdDeployDate -match 'sun')
                {
                   $newProdStartDate = $newProdDeployDate + ' ' + "Starting at 10:00"

                   #Use "regex" to determine the existing/prod start date already in the PROD BOIP in Format (abrev-Day MM/dd/yy starting at HH:MM)
                   $syncHash.message = "Info: Determining Existing Start Date & Time..."
                   $range.Text -match '([A-Za-z]{3}\s\d{1,2}[/]\d{1,2}[/]\d{2,4} Starting at \d{1,2}[:]\d{2})'
                   try 
                   {
	                   $oldProdStartDate = $matches[1]
                    
                   }
                   catch
                   {

                       $syncHash.message = "Verbose: Production start date not found. Skipping..."
                       Message-log($syncHash.message)
                       $skipped++
                   }

                   #Prompt User Updating Start Date in Progress
                   $syncHash.message = "Production start date not found."
                   Message-log($syncHash.message)

                   #Object Selection in MS Word to Find and Repleace existing Prod Start Date with New Start Date.
                   $a = $objSelection.Find.Execute($oldProdStartDate,$MatchCase,$MatchWholeWord,$MatchWildcards,$MatchSoundsLike,$MatchAllWordForms,$Forward,$Wrap,$Format,$newProdStartDate,$wdReplaceAll)
                
                   If($a -eq 'true')
                   {
                      $syncHash.message = "Update: Start Date Successfully Updated For Sunday Deployment."
                      Message-log($syncHash.message)
                      $success++

                      $newReadyForBusDate = (Get-Date $newProdDeployDate -Format "ddd M/dd/yy")
                   } ELSE {
                      $syncHash.message = "Verbose: $boipName Start Date was not Updated Skipping For Sunday Deployment."
                      Message-log($syncHash.message)
                      $skipped++
                   }#If New Deployment Date Contains "FRI' for FRI. Update Start time & Date

                } ELSEIF ($newProdDeployDate -match 'fri'){
                   $newProdStartDate = $newProdDeployDate + ' ' + "Starting at 18:30"
                   #Use "regex" to determine the existing/prod start date already in the PROD BOIP in Format (abrev-Day MM/dd/yy starting at HH:MM)
                   $syncHash.message = "Info: Determining Existing Start Date..."
                   Message-log($syncHash.message)
                   $range.Text -match '([A-Za-z]{3}\s\d{1,2}[/]\d{1,2}[/]\d{2,4} Starting at \d{1,2}[:]\d{2})'
                   try 
                   {
	                   $oldProdStartDate = $matches[1]
                    
                   }
                   catch
                   {
	                   #Write-Host "`n$boip start date could not be found. Skipping...`n" -ForegroundColor Yellow
                       $syncHash.message = "Verbose: $boipName start date could not be found. Skipping..."
                       Message-log($syncHash.message)
                       $skipped++
                   }

                   #Prompt User Updating Start Date in Progress
                   $syncHash.message = "Info: $boip Updating Start Date..."
                   Message-log($syncHash.message)

                   #Object Selection in MS Word to Find and Repleace existing Prod Start Date with New Start Date.
                   $a = $objSelection.Find.Execute($oldProdStartDate,$MatchCase,$MatchWholeWord,$MatchWildcards,$MatchSoundsLike,$MatchAllWordForms,$Forward,$Wrap,$Format,$newProdStartDate,$wdReplaceAll)
                
                   If($a -eq 'true')
                   {
                      #Write-Host "`n$boip Start Date Successfully Updated For Friday Deployment" -ForegroundColor Green
                      $syncHash.message = "Updated: $boipName Start Date Successfully Updated For Friday Deployment."
                      Message-log($syncHash.message)

                      #Update Prod Deploy Date by one day if Prod Deployment Date is Friday
                      $newReadyForBusDate = (Get-Date $newProdDeployDate).AddDays(1) 
                      $newReadyForBusDate = (Get-Date $newReadyForBusDate -Format "ddd M/dd/yy")
                      $success++
                   } ELSE {
                      #Write-Host "`n$boip Start Date was not Updated Skipping For Friday Deployment..." -ForegroundColor Yellow
                      $syncHash.message = "Verbose: $boipName Start Date was not Updated Skipping For Friday Deployment."
                      Message-log($syncHash.message)
                      $skipped++
                   }
                }
                

                If($boipName -like 'BOIP_PROD*'){
                    #Use "regex" to determine the existing/prod Ready-For-Business date already in the PROD BOIP in Format (abrev-Day MM/dd/yy)
                    $syncHash.message = "Info: Determining $boipName Existing Ready-For-Business..."
                    Message-log($syncHash.message)
                    $range.Text -match '(SAT \d{1,2}[/]\d{1,2}[/]\d{2,4} Starting at \d{1,2}[:]\d{2})'
                    try 
                    {
	                    $readyForBusDate = $matches[0]
               
                    }
                    catch
                    {
                        $syncHash.message = "Warning: $boipName Existing Ready-For-Businesdate is incorrect or could not be found."
                        Message-log($syncHash.message)
                        $skipped++
                    }

                    #Prompt User Updating Ready-For-Business date
                    $syncHash.message = "Info: Updating $boipName Ready For Business date..."
                    Message-log($syncHash.message)

                    If($newReadyForBusDate -match 'SAT')
                    {
                        $newReadyForBusDate = $newReadyForBusDate + ' ' + "Starting at 11:00"
                    }ELSEIF($newReadyForBusDate -match 'SUN'){
                        #Update Prod Deploy time frame
                        $newReadyForBusDate = (Get-Date $newReadyForBusDate -Format "ddd M/dd/yy")
                        $newReadyForBusDate = $newReadyForBusDate + ' ' + "Starting at 21:00"
                    }

                    #Object Selection in MS Word to Find and Repleace existing Prod Start Date with New Start Date.
                    $a = $objSelection.Find.Execute($readyForBusDate,$MatchCase,$MatchWholeWord,$MatchWildcards,$MatchSoundsLike,$MatchAllWordForms,$Forward,$Wrap,$Format,$newReadyForBusDate,$wdReplaceAll)
                
                    If($a -eq 'true')
                    {
                        #Write-Host "`n$boip Start Date Successfully Updated For Friday Deployment" -ForegroundColor Green
                        $syncHash.message = "Update: $boipName Start Date Successfully Updated For Friday Deployment."
                        Message-log($syncHash.message)
                        $success++
                    } ELSE {
                         $syncHash.message = "Verbose: $boipName does not exist. Skipping..."
                         Message-log($syncHash.message)
                         $skipped++
                    }
                }

                #Save & Close the Prod BOIP
                $objDoc.Save()
                $objWord.Quit()
                $syncHash.message = "Update: $boipName deployment date changes have been successfully made."
                Message-log($syncHash.message)
             } ELSE{
                $syncHash.message = "Verbose: $boipName does not exist. Skipping..."
                Message-log($syncHash.message)
                $skipped++
             }
        }

    ##################
    # Update QA BOIP #
    ##################

        #Grab the directory+name of the QA BOIP in the new BOIP dir
        $qaBOIP = Get-ChildItem $currentBoipPath -Recurse -Include "BOIP_QA*.docx" | ForEach-Object -Process {$_.FullName}

        if(Test-Path $qaBOIP)
        {
            #Open the QA BOIP
            $objWord = New-Object -comobject Word.Application  
            $objWord.Visible = $False  
            $objDoc = $objWord.Documents.Open($qaBOIP)
            $range = $objDoc.content
            $objSelection = $objWord.Selection
            $boipName = [System.IO.Path]::GetFileNameWithoutExtension($qaBOIP)

            #Display Boip name in GUI
                $syncHash.docNameDisplay.Dispatcher.Invoke("Normal",[action]{
                $syncHash.docNameDisplay.Text = $boipName
            })


            Determine-Boip-Content
             
             $syncHash.message = "Update: Updating $boipName Deployment Date..."
             $a = $objSelection.Find.Execute($oldQADeployDate,$MatchCase,$MatchWholeWord,$MatchWildcards,$MatchSoundsLike,$MatchAllWordForms,$Forward,$Wrap,$Format,$newQADeployDate,$wdReplaceAll)

             if($a -eq 'true')
             {
                
                $syncHash.message = "Update: $boipName Deployment Date Successfully Updated."
                Message-log($syncHash.message)
             } else {

                $syncHash.message = "Verbose: $boipName Deployment Date was not Successfully Updated. Skipping..."
                Message-log($syncHash.message)
             }

            #Save & Close the QA BOIP
            $objDoc.Save()
            $objWord.Quit()
            } else {
                $syncHash.message = "Verbose: $boipName was not found Skipping..."
                Message-log($syncHash.message)
        }

    ###################
    # Update DEV BOIP #
    ###################

        #Grab the directory+name of the Dev BOIP in the new BOIP dir
        $devBOIPS = Get-ChildItem $currentBoipPath -Recurse -Include "BOIP_DEV*.docx" | ForEach-Object -Process {$_.FullName}

        foreach($boip in $devBOIPS){
            if(Test-Path $boip)
            {
                #Open the Dev BOIP
                $objWord = New-Object -comobject Word.Application  
                $objWord.Visible = $False  
                $objDoc = $objWord.Documents.Open($boip)
                $range = $objDoc.content
                $objSelection = $objWord.Selection
                $boipName = [System.IO.Path]::GetFileNameWithoutExtension($boip)

                #Display Boip name in GUI
                $syncHash.docNameDisplay.Dispatcher.Invoke("Normal",[action]{
                    $syncHash.docNameDisplay.Text = $boipName
                })

                 
                Determine-Boip-Content

                $a = $objSelection.Find.Execute($oldDevDeployDate,$MatchCase,$MatchWholeWord,$MatchWildcards,$MatchSoundsLike,$MatchAllWordForms,$Forward,$Wrap,$Format,$newDevDeployDate,$wdReplaceAll)

                $syncHash.message = "Update: Updating $boipName Deployment Date..."
                Message-log($syncHash.message)
                if($a -eq 'true')
                {
                    $syncHash.message = "Update: $boipName Deployment Date Successfully Updated"
                    Message-log($syncHash.message)
                } else {
                    $syncHash.message = "Verbose: $boipName Deployment Date was not Successfully Updated. Skipping..."
                    Message-log($syncHash.message)
                }

                #Close the Dev BOIP
                $objDoc.Save()
                $objWord.Quit()
            } ELSE {
                $syncHash.message = "Verbose: $boipName not found Skipping..."
                Message-log($syncHash.message)
            }
        }

    ##################
    #Modify All BOIPS#
    ##################

    #Grab the directory+name of all the WORD (docx) files in the new BOIP dir
    $docxContents = Get-ChildItem $currentBoipPath -Recurse -Include "*.docx" | ForEach-Object -Process {$_.FullName}
    $prevReleaseNum = $prevReleaseNum.Trim('R',' ')
    $newReleaseNum = $newReleaseNum.Trim('R',' ')

    $currentBOIPCNR = 'Use' + ' ' + $prevCNR

    #Modify the contents of all of the WORD (docx) files
    foreach ($docxContent in $docxContents)
    {
	    $objWord = New-Object -comobject Word.Application  
	    $objWord.Visible = $False 
	    $objDoc = $objWord.Documents.Open($docxContent)
        $range = $objDoc.content

        $boipName = [System.IO.Path]::GetFileNameWithoutExtension($docxContent)

        #Display Boip name in GUI
        $syncHash.docNameDisplay.Dispatcher.Invoke("Normal",[action]{
            $syncHash.docNameDisplay.Text = $boipName
        })

	    #Remove any highlighting [usually used to determine if a step has been completed]
	    foreach ($docrange in $objDoc.Words)
	    {
		    $docrange.highlightColorIndex = [Microsoft.Office.Interop.Word.WdColorIndex]::WdAuto
	    }
	
	    $objSelection = $objWord.Selection

	    #Find and replace the contents of the variables
	    $syncHash.message ="Info: Replacing contents in $boipName..."
        Message-log($syncHash.message)
    
	    #Find and replace previous CNR with latest CNR
        $a = $objSelection.Find.Execute($prevCNR,$MatchCase,$MatchWholeWord,$MatchWildcards,$MatchSoundsLike,$MatchAllWordForms,$Forward,$Wrap,$Format,$newCNR,$wdReplaceAll)

        $syncHash.message ="Update: Updating CNR Number in $boipName"
        Message-log($syncHash.message)
        if($a -eq 'true')
        {
            $syncHash.message = "Update: CNR Successfully Updated in $boipName"
            Message-log($syncHash.message)
        }ELSE {
            $syncHash.message = "Verbose: CNR was not Successfully Updated in $boipName. Skipping..."
            Message-log($syncHash.message)
        }

        #Use "regex" to determine the existing/oldBackoutDate already in the PROD BOIP
        $syncHash.message = "Info: Determining $boipName Existing Backout CNR..."
        $range.Text -match '(Use SNOW-\d{5})'
        try 
        {
	        $oldBackoutCNR = $matches[1]
        }
        catch
        {
	        $syncHash.message = "Verbose: old backout date not found in $boipName. Skipping..."
            Message-log($syncHash.message)
        }

        $b = $objSelection.Find.Execute($oldBackoutCNR,$MatchCase,$MatchWholeWord,$MatchWildcards,$MatchSoundsLike,$MatchAllWordForms,$Forward,$Wrap,$Format,$newBackoutCNR,$wdReplaceAll)

        $syncHash.message = "Updating BOIP Backout CNR in $boipName."
        If($b -eq 'true')
        {
            $syncHash.message = "Update: $boipName Backout CNR Successfully Updated."
            Message-log($syncHash.message)
        } ELSE {
            $syncHash.message = "Verbose: $boipName BOIP Backout CNR was not Successfully Updated. Skipping..."
            Message-log($syncHash.message)
        }

        $c = $objSelection.Find.Execute($prevReleaseNum,$MatchCase,$MatchWholeWord,$MatchWildcards,$MatchSoundsLike,$MatchAllWordForms,$Forward,$Wrap,$Format,$newReleaseNum,$wdReplaceAll)

        $syncHash.message = "Update: Updating $boipName BOIP Title"
        If($c -eq 'true')
        {
            $syncHash.message = "Update: $boipName BOIP Title Successfully Updated."
            Message-log($syncHash.message)
        } ELSE {
            $syncHash.message = "Verbose: $boipName BOIP Title was not Successfully Updated. Skipping..."
            Message-log($syncHash.message)
        }

        if(Test-Path $vendorUpdatesPath){
            $customReleaseFolder = (Get-ChildItem $vendorUpdatesPath | Sort-Object -Descending -Property LastWriteTime | Where-Object {$_.PSIsContainer -eq $true -and $_.Name -like "*Custom_Build*"} | Select-Object -First 1)
            $latestCustomRelease = ($vendorUpdatesPath + '\'+ $customReleaseFolder.Name)

            if(Test-Path $latestCustomRelease)
            {
                $syncHash.message = "Update: Custom Release Folder For Backout Procedure was Found."
                Message-log($syncHash.message)

                $filePathOne = Get-ChildItem -Path "$latestCustomRelease" -Filter "*.msi" -Recurse
                $filePathTwo = Get-ChildItem -Path "$latestCustomRelease\*" -Filter "*.msi" -Recurse

                if($filePathOne = $True){
                    $latestCustomRelease= ($latestCustomRelease + $filePathOne)
                }elseif($filePathOne = $True){
                    $latestCustomRelease = ($latestCustomRelease + $filePathTwo)
                }else{
                    $syncHash.message = "Verbose: File Path Could not be found! Skipping"
                    Message-log($syncHash.message)
                }

            }else{
                $syncHash.message =  "Verbose: A Custom Release Folder For Backout Procedure was Not Found!"
                Message-log($syncHash.message)
            }
        
                $d = $objSelection.Find.Execute($oldReleaseNum,$MatchCase,$MatchWholeWord,$MatchWildcards,$MatchSoundsLike,$MatchAllWordForms,$Forward,$Wrap,$Format,$newCRPath,$wdReplaceAll)

                $syncHash.message = "Update: Updating $boipName Custom Release File Path"
                Message-log($syncHash.message)
                if($d -eq 'true')
                {
                    $syncHash.message = "Update: $boipName Custom Release File Path Successfully Updated"
                    Message-log($syncHash.message)
                } else {
                    $syncHash.message = "Verbose: $boipName Custom Release File Path was not Successfully Updated. Skipping..."
                    Message-log($syncHash.message)
                }
            }else{
                $syncHash.message = "Warning: Vendor supplied updates path could not be found. Skipping..."
                Message-log($syncHash.message)
            }

        $objDoc.Save()
	    $objWord.Quit()
    }
        $syncHash.message = "Update: Updates have been completed."
        Message-log($syncHash.message) 
    }

Function Message-log()
{
    param(
		[Parameter(Position = 0,
				   Mandatory = $true,
				   ValuefromPipelineByPropertyName = $true,
				   ValuefromPipeline = $true)]
		[system.string] $message
        
	)

        $script:messages = $syncHash.message 
    
        #foreach($message in $messages)
        #{
            $syncHash.updatePageTB.Dispatcher.Invoke("Normal",[action]{
                $Run = New-Object System.Windows.Documents.Run
                 Write-Verbose ("Type: {0}" -f $message) -Verbose
                    Switch -regex ($message) {
                        "^Verbose" {
                         $Run.Foreground = "Yellow"
                         }
                         "^Warning" {
                            $Run.Foreground = "Red"
                         }
                         "^Info" {
                             $Run.Foreground = "White"
                         }
                         "^Update" {
                            $Run.Foreground = "Green"
                            }
                         }
             
                         $Run.Text = ("{0}" -f $message)
                         Write-Verbose ("Adding a new line") -Verbose
                         $syncHash.updatePageTB.Inlines.Add($Run)
                         Write-Verbose ("Adding a new linebreak") -Verbose
                         $syncHash.updatePageTB.Inlines.Add((New-Object System.Windows.Documents.LineBreak))
    
                })
          #}


    $syncHash.updatePageScrollView.Dispatcher.Invoke("Normal",[action]{
    $syncHash.updatePageScrollView.ScrollToEnd()
        
    })
    
}