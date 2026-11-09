# Runs the Flutter web app without depending on the Flutter CDN.
# The CDN is often blocked on local networks, which otherwise leaves the
# browser on a blank page because CanvasKit cannot be downloaded.
$ErrorActionPreference = 'Stop'

$apiBase = if ($env:API_BASE_URL) {
    $env:API_BASE_URL
} else {
    'http://localhost:8081/api'
}

Write-Host "Starting Purana Bazaar web app against $apiBase" -ForegroundColor Green
flutter run -d chrome --no-web-resources-cdn "--dart-define=API_BASE_URL=$apiBase"
