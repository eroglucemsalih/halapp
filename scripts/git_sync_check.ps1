Write-Host "== Git Sync Check Starting ==" -ForegroundColor Cyan
$cwd = Get-Location
Write-Host "Working directory: $cwd`n" -ForegroundColor DarkCyan

# 1) Basic status and branch info
Write-Host "-- git status --" -ForegroundColor Yellow
git status 2>&1 | ForEach-Object { Write-Host $_ }

Write-Host "`n-- Remote URLs --" -ForegroundColor Yellow
git remote -v 2>&1 | ForEach-Object { Write-Host $_ }

Write-Host "`n-- Branch info --" -ForegroundColor Yellow
$current = git rev-parse --abbrev-ref HEAD 2>$null
if ($current) { Write-Host "Current branch: $current" } else { Write-Host "Current branch: (none detected)" }
git branch -a 2>&1 | ForEach-Object { Write-Host $_ }

# 2) Show recent local commits
Write-Host "`n-- Last 10 local commits --" -ForegroundColor Yellow
git log --oneline -n 10 2>&1 | ForEach-Object { Write-Host $_ }

# 3) Fetch origin (safe, read-only network update)
Write-Host "`n-- Fetching origin (read-only) --" -ForegroundColor Yellow
try {
	git fetch origin 2>&1 | ForEach-Object { Write-Host $_ }
} catch {
	Write-Host "git fetch failed: $_" -ForegroundColor Red
}

# 4) Show origin/main recent commits
Write-Host "`n-- origin/main last 10 commits (if available) --" -ForegroundColor Yellow
git log origin/main --oneline -n 10 2>&1 | ForEach-Object { Write-Host $_ }

# 5) Compare local branch with origin/main
$localBranch = (git rev-parse --abbrev-ref HEAD 2>$null).Trim()
if (-not $localBranch) { $localBranch = "main" }

Write-Host "`n-- local vs origin comparison (short) --" -ForegroundColor Yellow
$counts = git rev-list --left-right --count $localBranch...origin/main 2>$null
if ($counts) {
	if ($counts -match "^(\d+)\s+(\d+)$") {
		$ahead = [int]$Matches[1]
		$behind = [int]$Matches[2]
		Write-Host "Local branch '$localBranch' is $ahead commits ahead and $behind commits behind origin/main." -ForegroundColor Cyan
		if ($behind -gt 0) { Write-Host "Suggestion: run: git pull --rebase origin main" -ForegroundColor Green }
		if ($ahead -gt 0) { Write-Host "Suggestion: run: git push origin $localBranch" -ForegroundColor Green }
	} else {
		Write-Host "Unexpected format from rev-list: $counts" -ForegroundColor Yellow
	}
} else {
	Write-Host "Could not compare branches. origin/main may not exist or fetch failed." -ForegroundColor Red
}

# 6) index.lock check
if (Test-Path ".git\index.lock") {
	Write-Host "WARNING: .git\index.lock exists. If no git process is running, remove it: Remove-Item .git\index.lock" -ForegroundColor Red
}

# 7) Maintenance suggestions
Write-Host "`nMaintenance suggestions (if you see 'too many loose objects' or similar):" -ForegroundColor Yellow
Write-Host "  git reflog expire --expire=now --all" -ForegroundColor DarkGray
Write-Host "  git gc --prune=now --aggressive" -ForegroundColor DarkGray
Write-Host "  git prune" -ForegroundColor DarkGray

# 8) Quick checklist
Write-Host "`nQuick checklist:" -ForegroundColor Yellow
Write-Host "- Are you in the project root? (Get-Location)" -ForegroundColor DarkGray
Write-Host "- Which branch are you on? (git branch --show-current)" -ForegroundColor DarkGray
Write-Host "- Is remote URL correct? (git remote -v)" -ForegroundColor DarkGray
Write-Host "- If using GitHub Desktop, open the repo there and press 'Fetch origin'." -ForegroundColor DarkGray

Write-Host "`n== Done. If you want, I can add options to perform 'git pull --rebase' or 'git reset --hard origin/main' (warning: reset --hard will discard local changes)." -ForegroundColor Cyan

# End of script

















































# Script sonuWrite-Host "`n== Tamamlandı. Eğer isterseniz otomatik olarak 'pull --rebase' yapmamı sağlayan komut ekleyebilirim (uyarı: çatışma olursa müdahale gerekir)." -ForegroundColor CyanWrite-Host "- GitHub Desktop kullanıyorsanız repository yolunu kontrol edin ve 'Fetch origin' tıklayın." -ForegroundColor DarkGrayWrite-Host "- Remote URL doğru mu? (git remote -v)" -ForegroundColor DarkGrayWrite-Host "- Hangi branch'tesiniz? (git branch --show-current)" -ForegroundColor DarkGrayWrite-Host "- Çalıştığınız dizin gerçekten proje kökü mü? (Get-Location)" -ForegroundColor DarkGray# 8) Eğer repo website'de görünüyorsa ama masaüstünde değilse: kontrol listesi
nWrite-Host "`nKontrol listesi (kısa):" -ForegroundColor YellowWrite-Host "  git prune" -ForegroundColor DarkGrayWrite-Host "  git gc --prune=now --aggressive" -ForegroundColor DarkGrayWrite-Host "  git reflog expire --expire=now --all" -ForegroundColor DarkGrayWrite-Host "`nBakım önerileri (eğer 'too many loose objects' veya benzeri hatalar alıyorsanız):" -ForegroundColor Yellow# 7) Git bakım önerileri (koruyucu, yalnızca öneri)}    Write-Host "UYARI: .git\index.lock dosyası mevcut. Eğer hiçbir git işlemi çalışmıyorsa kaldırabilirsiniz: Remove-Item .git\index.lock" -ForegroundColor Red# 6) Check for index.lock or repository warnings
nif (Test-Path .git\index.lock) {}    Write-Host "Karşılaştırma yapılamadı. origin/main yok olabilir veya fetch başarısız oldu." -ForegroundColor Redelse {}    }        }            Write-Host "Öneri: Yerel commit'leri uzakla paylaşmak için: `git push origin $localBranch`" -ForegroundColor Green        if ($ahead -gt 0) {        }            Write-Host "Öneri: Uzakta olan değişiklikleri almak için: `git pull --rebase origin main` veya önce `git fetch origin` sonra farkları inceleyin." -ForegroundColor Green        if ($behind -gt 0) {        Write-Host "Local branch '$localBranch' is $ahead commits ahead and $behind commits behind origin/main." -ForegroundColor Cyan        $behind = [int]$parts[1]        $ahead = [int]$parts[0]    if ($parts.Length -ge 2) {    $parts = $counts -split "\s+"# 5) Show diff summary if there are commits different
n$counts = git rev-list --left-right --count $localBranch...origin/main 2>$null
nif ($counts) {
nWrite-Host "`n-- local vs origin karşılaştırması (kısa) --" -ForegroundColor Yellow
ngit rev-list --left-right --count $localBranch...origin/main 2>&1 | ForEach-Object { Write-Host $_ }Write-Host "`n-- origin/main son 10 commit --" -ForegroundColor Yellow
ngit log origin/main --oneline -n 10 2>&1 | ForEach-Object { Write-Host $_ }if (-not $localBranch) { $localBranch = "main" }$localBranch = (git branch --show-current).Trim()# 4) Compare local main with origin/main if both existWrite-Host "`n-- Fetching origin (güncel uzaktan referansları alıyorum)... --" -ForegroundColor Yellow
ngit fetch origin 2>&1 | ForEach-Object { Write-Host $_ }# 3) Fetch origin (safe, read-only network update)ngit log --oneline -n 10 2>&1 | ForEach-Object { Write-Host $_ }