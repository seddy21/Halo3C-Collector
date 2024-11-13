Clear-Host
[Console]::CursorVisible = $false
Add-Type -AssemblyName System.Web

# Update these variables
$global:ListenerURL = "http://<your listening server here>:8081/heartbeat/"    # Define the URL prefix to listen on .. should match what is set on the Halo units  (e.g., http://192.168.1.200:8081/)

$global:InfluxBaseURL = "http://<your influxdb server here>:8086"          # Define the URL your Influx Database server is running on (default port 8086)
$global:InfluxDatabase = "VapeDetectors"                               # Define the database you're writing to
$global:InfluxMeasurement = "HALO3C"                                   # Define the name of the measurement you are collecting
$global:InfluxRetentionPolicy = "DYNAMIC"                              # Define the Retention Policy being used

$global:SMTPFrom = "<your from email>"
$global:SMTPTo = "<your to email>"
$global:SMTPServer = "<your SMTP server"
$global:SMTPPort = 25
$global:SMTPAlertsEnable = $true
$global:SMTPUser = "<your smtp user account>"
$global:SMTPPass = "<your smtp user password>"

#Do not modify these
$global:InfluxURL = "$InfluxBaseURL/write?db=$InfluxDatabase&rp=$InfluxRetentionPolicy"

## SendEmail
Function SMTPSend {
    [CmdletBinding()]
    Param([String]$subject,[String]$body)

    $password = ConvertTo-SecureString $settings.app.smtppass -AsPlainText -Force

    # Create email object
    $email = New-Object System.Net.Mail.MailMessage
    $email.From = $settings.app.smtpfrom
    $email.To.Add($settings.app.smtpto)
    $email.Subject = $subject
    $email.Body = $body

    # Set SMTP server and credentials
    $smtp = New-Object System.Net.Mail.SmtpClient($SMTPServer, $SMTPPort)
    $smtp.EnableSSL = $false
    $smtp.Credentials = New-Object System.Net.NetworkCredential($SMTPUser, $SMTPPass)

    # Send email
    try {
        $smtp.Send($email)
    } catch {
        Write-Host "Failed to send email. Error: $($_.Exception.Message)"
    }
}

Function Write-InfluxDB($body) {
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

Function Avaluate-Alerts($Location,$Metric,$Value) {

    Switch ($Metric){
        "PM25"{If($Value -gt 51){SMTPSend "Probable Vape Detect, $Location","Vaping detected at $Location."}}
        "PM10"{If($Value -gt ){SMTPSend "Probable Vape Detect, $Location","Vaping detected at $Location."}}
        "Tamper"{}
    }

}

<#Main#> {

    # Create a new HttpListener object
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add($ListenerURL)
    $listener.Start()

    Write-Host "HALO 3C Heartbeat data collection.." -ForegroundColor Green
    Write-Host "Listening for incoming HTTP requests at: " -NoNewline;Write-Host $ListenerURL -ForegroundColor Cyan
    Write-Host "Writing data to: " -NoNewline;Write-Host $InfluxURL -ForegroundColor Cyan
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
                
                # Display the received parameters
                if ($queryParams.ContainsKey("location") -and $queryParams.ContainsKey("Temp")) {
                    
                    $location = $queryParams["location"]
                    $temperature = $queryParams["Temp"]
                    $RH = $queryParams["RH"]
                    $LightLevel = $queryParams["Lux"]
                    $TVOC = $queryParams["TVOC"]
                    $CarbonDioxide = $queryParams["CO2eq"]
                    $FineParticulateMed = $queryParams["PM2.5"]
                    $FineParticulateLg = $queryParams["PM10"]
                    $Ammonia = $queryParams["NH3"]
                    $NitrogenDioxide = $queryParams["NO2"]
                    $CarbonMonoxide = $queryParams["CO"]
                    $Noise = $queryParams["Noise"]
                    $Tamper = $queryParams["Move"]
                    $Motion = $queryParams["Motion"]
                    $AirQuality = $queryParams["AQI"]
                    $Events = $queryParams["EVENTS"]

                    

                    $body="$InfluxMeasurement,Location=$($location) Temp=$temperature,RelativeHumidity=$RH,LightLevel=$LightLevel,TVOC=$TVOC,CO2=$CarbonDioxide,$("PM2.5")=$FineParticulateMed,PM10=$FineParticulateLg,Ammonia=$Ammonia,NO2=$NitrogenDioxide,CO=$CarbonMonoxide,Noise=$Noise,Motion=$Motion,Tamper=$Tamper,AQI=$AirQuality"

                    Write-Host "*" -ForegroundColor Red -NoNewline
                    Write-InfluxDB $body 

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
        } catch {
            Write-Host "Error handling request: $_"
        }
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

    $listener.Stop()

}