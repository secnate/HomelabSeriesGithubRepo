# CPU Stress Test
Write-Host "Starting CPU stress (single core)..." -ForegroundColor Green
$end = (Get-Date).AddMinutes(5)

# The continuous mathematical operations will stress a CPU
while ((Get-Date) -lt $end) {
    $x = 0
    while ($x -lt 100000) {
        $result = [Math]::Sqrt($x) * [Math]::Sqrt($x)
        $x++
    }
}

Write-Host "CPU stress complete!" -ForegroundColor Green