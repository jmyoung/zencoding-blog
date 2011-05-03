//
// Pipe in VMs to this script to get their sizes on disk
//

Begin {

}

Process {
	$vm = $_

	$report = $vm | select Name, Id, Size, Used
	$report.Size = 0
	$report.Used = 0

	$vmview = $vm | Get-View
	foreach($disk in $vmview.Storage.PerDatastoreUsage){ 
   		$dsview = (Get-View $disk.Datastore)
		#$dsview.RefreshDatastoreStorageInfo()
		$report.Size += (($disk.Committed+$disk.Uncommitted)/1024/1024/1024)
		$report.Used += (($disk.Committed)/1024/1024/1024)
	} 

	$report.Size = [Math]::Round($report.Size, 2)
	$report.Used = [Math]::Round($report.Used, 2)

	Write-Output $report
}

End {

}

