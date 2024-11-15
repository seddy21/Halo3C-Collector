# Input string
$string = "Health_Index=1,AQI=8,PM2.5=1,TVOC=6,CO2cal=449,Humidity=30!,Temp_F=74,Vape=0,THC=0,Masking=0,Smoking=0,Gunshot=0,Aggression=0,Tamper=23,Help=0,Motion=16"

Function ProcessEvents {
    [CmdletBinding()]
    Param([String]$strEvents)    
    # Initialize an array to hold the event name and reading pairs
    $result = @()
    
    # Split the string by commas, then process each key-value pair
    foreach ($pair in $string -split ',') {
        # Split the pair into event name and reading
        $event, $reading = $pair -split '='
        
        # Add the event name and reading as an object to the result array
        $result += [pscustomobject]@{ Event = $event; Reading = $reading }
    }
    
    $location = "Halo-BH-Mens"
    $body="HaloEvents,Location=$($location) "
    
    ForEach($Event in $result) {       
        If($Event.Reading[-1] -eq "!") {
            # This even is triggered, send alert..
            $reading = $Event.Reading.Substring(0,$Event.Reading.Length -1)
            Write-Host "$($event.Event) TRIGGERED!" -ForegroundColor Red
        }
        Else {
            $reading = "$($Event.Event)=$($Event.Reading),"
        }        
        $body += $reading    
    }
}

$body
