Clear-Host
[Console]::CursorVisible = $false
Add-Type -AssemblyName System.Web

####
#
# Update the below global variables
# Uncomment any alerts you would like to receive in the ProcessAlert Function
#

# HTTP Listener Settings
$global:ListenerURL = "http://<your listener server>:8081/heartbeat/"       # Define the URL prefix to listen on .. should match what is set on the Halo units  (e.g., http://192.168.1.200:8081/)

# InfluxDB Settings
$global:InfluxWriteEnable = $false
$global:InfluxBaseURL = "http://<your InfluxDB server>:8086"                # Define the URL your Influx Database server is running on (default port 8086)
$global:InfluxDatabase = "VapeDetectors"                                    # Define the database you're writing to
$global:InfluxMeasurement = "HALO3C"                                        # Define the name of the measurement you are collecting
$global:InfluxRetentionPolicy = "DYNAMIC"                                   # Define the Retention Policy being used

# SMTP Settings
$global:SMTPAlertsEnable = $false                                           # Set to $true to enable
$global:SMTPFrom = "<your from email>"                                      # Define from email address 
$global:SMTPTo = "<your to email>"                                          # Define to email address(s) (comma seperated)
$global:SMTPServer = "<your smtp server>"                                   # Define SMTP server
$global:SMTPPort = 25                                                       # Define SMTP port
$global:SMTPUser = "<username for smtp authentication>"                     # User name for authentication
$global:SMTPPass = "<password for smtp authentication>"                     # Password for authentication

# MS Teams Settings
# The MS Teams WebHook is depricated. This should be replaced with the Microsoft Graph API & Power Automate prior to 1/25/25
$global:TeamsAlertsEnable = $false
$global:TeamsWebHookURL = "<your URL for Teams WebHook>"

# Do not modify!
$global:InfluxURL = "$InfluxBaseURL/write?db=$InfluxDatabase&rp=$InfluxRetentionPolicy"

Function SMTPSend {
    [CmdletBinding()]
    Param([String]$subject,[String]$emailBody)

    try {
        $password = ConvertTo-SecureString $SMTPPass -AsPlainText -Force

        # Create email object
        $email = New-Object System.Net.Mail.MailMessage
        $email.From = $SMTPFrom
        $email.To.Add($SMTPTo)
        $email.Subject = $subject
        $email.Body = $emailBody

        # Set SMTP server and credentials
        $smtp = New-Object System.Net.Mail.SmtpClient($SMTPServer, $SMTPPort)
        $smtp.EnableSSL = $false
        $smtp.Credentials = New-Object System.Net.NetworkCredential($SMTPUser, $password)

        # Send email
        $smtp.Send($email)
    } catch {
        Write-Host "Failed to send email. Error: $($_.Exception.Message)"
    }
}
Function TeamsSend {
    [CmdletBinding()]
    Param([string] $messageBody)

    try{
        $message = @{
            text = $messageBody
        }

        $jsonMessage = $message | ConvertTo-Json -Depth 3
        $res = Invoke-RestMethod -Uri $TeamsWebHookURL -Method Post -ContentType 'application/json' -Body $jsonMessage
    }
    catch{
        <#Do this if a terminating exception happens#>
        Write-Host $_
        Write-Host "An error occurred: $($_.Exception.Message)"
        Write-Host "Line number: $($_.InvocationInfo.ScriptLineNumber)"
        Write-Host "Stack trace: $($_.Exception.ScriptStackTrace)"
    }
    If($res -eq 1){
        # Do something .. or not.
    }
}

# Uncomment any alert you wish to receive.
Function ProcessAlert {
    [CmdletBinding()]
    Param([String]$thisLocation,[String]$thisMetric)

    try {
        $td = Get-Date

        Switch ($thisMetric){
            #"Health_Index"{$AlertMessage = @("Health Index Alert","$td --- Health Index alert triggered at $thisLocation.")}
            #"AQI"{$AlertMessage = @("AQI Alert","$td --- AQI alert triggered at $thisLocation.")}
            #"PM2.5"{$AlertMessage = @("PM2.5 Alert","$td --- PM2.5 alert triggered at $thisLocation.")}
            #"TVOC"{$AlertMessage = @("TVOC Alert","$td --- TVOC alert triggered at $thisLocation.")}
            #"CO2cal"{$AlertMessage = @("CO2 Alert","$td --- Temperature alert triggered at $thisLocation.")}
            #"Humidity"{$AlertMessage = @("Humidity Alert","$td --- Humidity alert triggered at $thisLocation.")}
            #"Temp_F"{$AlertMessage = @("Temperature Alert","$td --- Temperature alert triggered at $thisLocation.")}
            "Vape"{$AlertMessage = @("Vape Detected","$td --- Vaping detected at $thisLocation.")}
            "THC"{$AlertMessage = @("THC Detected","$td --- THC detected at $thisLocation.")}
            "Masking"{$AlertMessage = @("Masking Detected","$td --- Masking detected at $thisLocation.")}
            "Smoking"{$AlertMessage = @("Smoking Detected","$td --- Smoking detected at $thisLocation.")}
            "Gunshot"{$AlertMessage = @("Gunshot Detected","$td --- Gunshot detected at $thisLocation.")}
            "Aggression"{$AlertMessage = @("Aggression Detected","$td --- Aggression detected at $thisLocation.")}
            "Tamper"{$AlertMessage = @("Tamper Detected","$td --- Tamper detected at $thisLocation.")}
            "Help"{$AlertMessage = @("Help Request Detected","$td --- Help request detected at $thisLocation.")}
            #"Motion"{$AlertMessage = @("Motion Alert","$td --- Motion alert triggered at $thisLocation.")}
        }
        
        If($null -ne $AlertMessage) {
            If($SMTPAlertsEnable -eq $true) {
                SMTPSend $AlertMessage[0] $AlertMessage[1]
            }

            If($TeamsAlertsEnable -eq $true) {
                TeamsSend $AlertMessage[1]
            }
        }
    }
    catch {
        <#Do this if a terminating exception happens#>
        Write-Host $_
        Write-Host "An error occurred: $($_.Exception.Message)"
        Write-Host "Line number: $($_.InvocationInfo.ScriptLineNumber)"
        Write-Host "Stack trace: $($_.Exception.ScriptStackTrace)"
    }
}
Function ProcessEvents {
    [CmdletBinding()]
    Param([hashtable]$queryParams)

    try {

        $location = [string]$queryParams["location"]

        ForEach($Metric in $queryParams.keys) {            
            If([string]$Metric -ne "location") {
                $Value = [string]$queryParams[$Metric]
                $cleanMetric = $Metric.ToString()
                $cleanMetric =  $cleanMetric -replace ("\.","")
                $reading = "$($cleanMetric)=$($Value),"
                $InfluxQuery += $reading
                               
                # Check if event has been triggered
                If($Value[-1] -eq '!') {ProcessAlert $location $cleanMetric}
            }
        }        
        $InfluxQuery = (($InfluxQuery.TrimEnd(",")) -replace ("\!","")) 
    }
    catch {
        <#Do this if a terminating exception happens#>
        Write-Host $_
        Write-Host "An error occurred: $($_.Exception.Message)"
        Write-Host "Line number: $($_.InvocationInfo.ScriptLineNumber)"
        Write-Host "Stack trace: $($_.Exception.ScriptStackTrace)"   
        $InfluxQuery = "Error"
    }
    Return $InfluxQuery
}
Function Write-InfluxDB {
    [CmdletBinding()]
    Param([String]$body)

    try {

        $response = Invoke-webrequest -UseBasicParsing -Uri $InfluxURL -Body $body -method Post    
        
        If ($response.StatusCode -ne 204){
            Write-Host $response.StatusDescription
        }
    }
    catch {
        Write-Host "InfluxDB Write error: $_.Exception.Message"
    }
}

# Create a new HttpListener object
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($ListenerURL)
$listener.Start()

Write-Host "HALO 3C Heartbeat data collection.." -ForegroundColor Green
Write-Host "Listening for incoming HTTP requests at: " -NoNewline;Write-Host $ListenerURL -ForegroundColor Cyan
Write-Host "Writing data to: " -NoNewline;Write-Host $InfluxURL -ForegroundColor Cyan

If($SMTPAlertsEnable -eq $false){Write-Host "SMTP Alerts Disabled!" -ForegroundColor Red}
If($InfluxWriteEnable -eq $false){Write-Host "InfluxDB Writes Disabled!" -ForegroundColor Red}
If($TeamsAlertsEnable -eq $false){Write-Host "Teams Alerts Disabled!" -ForegroundColor Red}

Write-Host "Press [ESC] to stop listener.." -ForegroundColor Yellow

# Infinite loop to keep the listener running
while ($listener.IsListening) {

    try {
        # Wait for an incoming request
        $context = $listener.GetContext()

        # Get the HTTP request and response
        $request = $context.Request
        $response = $context.Response

        # Only respond to GET requests
        if ($request.HttpMethod -eq "GET") {
            #Write-Host "Received a GET request from $($request.RemoteEndPoint)"

            # Extract query parameters
            $query = $request.Url.Query
            $queryParams = @{}
            if ($query) {
                
                # Parse the query string into a hashtable
                $query -replace "^\?", "" -split "," | ForEach-Object {
                    $param = $_ -split "="
                    if ($param.Count -eq 2) {
                        $queryParams[$param[0]] = [System.Web.HttpUtility]::UrlDecode($param[1])
                    }
                }
            }
            
            # Process event readings
            if ($queryParams.ContainsKey("Location") -and $queryParams.ContainsKey("Vape")) {

                $location = [string]$queryParams["location"]
                $strEventsQry = ProcessEvents $queryParams
                $EventsBody="HaloEvents,Location=$location $strEventsQry"

                If($InfluxWriteEnable -eq $true) {
                    Write-InfluxDB $EventsBody 
                }
                else {
                    Write-Host $EventsBody
                }

                Write-Host "*" -ForegroundColor Red -NoNewline

            } else {
                Write-Host "Heartbeat received but missing parameters."
            }

            # Set a response message
            $responseMessage = "Heartbeat acknowledged."
            $buffer = [System.Text.Encoding]::UTF8.GetBytes($responseMessage)

            # Set the content type and length of the response
            $response.ContentType = "text/plain"
            $response.ContentLength64 = $buffer.Length

            # Send the response
            $response.OutputStream.Write($buffer, 0, $buffer.Length)
            $response.OutputStream.Close()
        } else {
            Write-Host "Received a non-GET request, ignoring."
        }
    }
    catch {
        Write-Host "Error handling request: $_"
        Write-Host "An error occurred: $($_.Exception.Message)"
        Write-Host "Line number: $($_.InvocationInfo.ScriptLineNumber)"
        Write-Host "Stack trace: $($_.Exception.ScriptStackTrace)"        
    }

    # Create 500 millisecond delay to allow for escape key press used to shutdown listener
    for($i = 0;$i -lt 5; $i++){
        Start-Sleep -Milliseconds 100
        # Check if a key is available
        if ([console]::KeyAvailable) {
            # Check if the key pressed is Escape
            $key = [console]::ReadKey($true)
            if ($key.Key -eq 'Escape') {
                Write-Host
                Write-Host "Escape key pressed. Listener stopped.." -ForegroundColor Red
                $listener.Stop()
                break
            }
        }       
    }

    Write-Host "`r$( ' ' * ($Host.UI.RawUI.WindowSize.Width - 1))`r" -NoNewline
    [Console]::CursorVisible = $false
}
