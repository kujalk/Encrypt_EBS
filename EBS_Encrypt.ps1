#Purpose - Create Encrypted Volume from Unencrypted volume
#Developer - K.Janarthanan
#Date - 1/5/2020

$ErrorActionPreference="Stop"

#Set AWS Region and Availability Zone
$region=Read-Host "Provide the region you want to connect"
Set-DefaultAWSRegion -Region $region

$counter = 1
$all_volumes=Get-EC2Volume | Select-Object @{ Name = "Volume_No" ; Expression= {$global:counter; $global:counter++}}, VolumeId,Attachments,VolumeType,Encrypted

if($all_volumes -eq $null)
{
    Write-Host "No EBS Volumes found in this region"
    exit 0
}

$all_volumes| Format-Table

$vol_no=Read-Host "Input Volume No You want to Encrypt "

$selected_vol=$all_volumes | Where-Object {($_.Volume_No -eq $vol_no) -and ($_.Encrypted -eq $False)}

if($selected_vol -eq $null)
{
    Write-Host "Volume is not eligible, either Volume No is invalid or this Volume is already encrypted" -ForegroundColor Red
    exit 0
}

#$selected_vol

#Create new snapshot
$new_snap=New-EC2Snapshot -VolumeId $selected_vol.VolumeID -Force 
$snap_id=$new_snap.SnapshotId

while($new_snap.State -eq 'pending')
{
    Write-Host "Snapshot Creation in progress..."
    Start-Sleep -s 5
    $new_snap=Get-EC2Snapshot -SnapshotId $snap_id
}

Write-Host "Snapshot Status is : $($new_snap.State)"

#Create new volume from snapshot with Encryption
if($new_snap.State -eq 'completed')
{
    Write-Host ""
    $az=Get-EC2AvailabilityZone | select ZoneName 
    $az | Format-Table

    $az_vol=Read-Host "Provide the Availability Zone"
    Write-Host "Going to create Encrypted Volume"
    $new_vol=New-EC2Volume -SnapshotId $new_snap.SnapshotId -Encrypted $true -AvailabilityZone $az_vol -Force
    $vol_id=$new_vol.VolumeId

    while($new_vol.State -eq 'creating')
    {
        Write-Host "Encrypt volume Creation in progress..."
        Start-Sleep -s 5
        $new_vol=Get-EC2Volume -VolumeId $vol_id
    }

    if($new_vol.State -eq 'available')
    {
        Write-Host "Created new Encrypted Volume with Volume ID - $($new_vol.VolumeId)"

        #Clean Snapshot
        Remove-EC2Snapshot -SnapshotId $new_snap.SnapshotId -Force

        Write-Host "Process completed!!!"
    }
    else 
    {
        Write-Host "Unable to create new Encrypted Volume"    
    }
}

else 
{
    Write-Host "Snapshot Status is $($new_snap.State). Therefore, unable to create Encrypted volume"    
}

