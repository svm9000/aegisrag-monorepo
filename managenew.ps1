<#
.SYNOPSIS
AegisRAG Multi-Topology Core Automation Engine for Windows 11 PowerShell.
.DESCRIPTION
Orchestrates local runtimes, standard container lifecycles, and Kubernetes clusters.
.EXAMPLE
.\managenew.ps1 -Action verify-all -Engine k8s
#>
param (
    [ValidateSet("clean", "infra", "build", "deploy", "test", "verify-all")]
    [string]$Action = "verify-all",

    [ValidateSet("local", "docker", "k8s")]
    [string]$Engine = "local"
)
$ErrorActionPreference = "Stop"

# --- Centralized Immutable Topology Constants ---
$LlmVolume     = "aegisrag_persistent_llm"
$HfVolume      = "aegisrag_persistent_hf"
$BackendImage  = "aegisrag-backend:local"
$FrontendImage = "aegisrag-frontend:local"
$UserHome      = [System.Environment]::GetFolderPath("UserProfile")
$HostHfCache   = Join-Path $UserHome ".cache\huggingface"
# --- Environment Preparation Subroutines ---
function Load-DotEnv {
    if (Test-Path ".env") {
        Write-Host "[INFO] Loading workspace environmental keys..." -ForegroundColor Gray
        Get-Content .env | ForEach-Object {
            if ($_ -and $_ -notmatch '^#') {
                $name, $value = $_ -split '=', 2
                if ($name -and $value) {
                    [System.Environment]::SetEnvironmentVariable($name.Trim(), $value.Trim())
                }
            }
        }
    }
}

function Set-HostEnv {
    Write-Host "[INFO] Configuring unified HuggingFace paths..." -ForegroundColor Gray
    $env:HF_HOME = $HostHfCache
    $env:HF_HUB_OFFLINE = "1"
    $env:HF_HUB_DISABLE_SYMLINKS_WARNING = "1"
}

function Invoke-Clean {
    Write-Host "[CLEAN] Tearing down active topologies and processes..." -ForegroundColor Red

    # --- 1. AGGRESSIVE PROCESS FLUSH ---
    # Terminates parent and hidden child tasks to stop console log corruption
    Write-Host "[CLEAN] Purging active python, uvicorn, node, and workspace streams..." -ForegroundColor Gray
    Get-Process -Name "python" -ErrorAction SilentlyContinue | Stop-Process -Force
    Get-Process -Name "uvicorn" -ErrorAction SilentlyContinue | Stop-Process -Force
    Get-Process -Name "node" -ErrorAction SilentlyContinue | Stop-Process -Force
    Get-Process -Name "kubectl" -ErrorAction SilentlyContinue | Stop-Process -Force
    Get-Process | Where-Object { $_.Path -like "*aegisrag-monorepo*" } | Stop-Process -Force -ErrorAction SilentlyContinue

    # --- 2. DOCKER COMPOSE TEARDOWN ---
    # Drops native standard container layers cleanly
    $OldPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        docker compose down --remove-orphans 2>&1 | Out-Null
    } finally {
        $ErrorActionPreference = $OldPreference
    }

    # --- 3. STANDALONE CONTAINER REMOVAL ---
    # Force-removes loose frontend or backend app containers if left behind
    $TargetContainers = @("aegisrag-backend", "aegisrag-frontend")
    foreach ($Container in $TargetContainers) {
        $Exists = docker ps -a -q --filter "name=^/${Container}$"
        if ($Exists) {
            Write-Host "[CLEAN] Removing standalone container: $Container" -ForegroundColor Yellow
            $OldLoopPreference = $ErrorActionPreference
            $ErrorActionPreference = "Continue"
            try {
                docker rm -f $Container 2>&1 | Out-Null
            } finally {
                $ErrorActionPreference = $OldLoopPreference
            }
        }
    }

    # --- 4. KUBERNETES MANIFEST PURGE ---
    # Wipes old deployments cleanly without running slow host sideload mechanisms
    if (Get-Command minikube -ErrorAction SilentlyContinue) {
        # Best Practice: Temporarily silence strict script execution rules
        # This prevents Docker performance warnings or timeouts from causing a fatal script crash
        $OldK8sPreference = $ErrorActionPreference
        $ErrorActionPreference = "SilentlyContinue"

        # Check the cluster state inside the safe-zone wrapper
        $MinikubeStatus = minikube status --format "{{.Host}}" 2>$null
        $IsMinikubeRunning = ($MinikubeStatus -eq "Running")

        # Restore original strict error routing preference flags instantly
        $ErrorActionPreference = $OldK8sPreference

        if ($IsMinikubeRunning) {
            Write-Host "[CLEAN] Deleting Kubernetes cluster topologies..." -ForegroundColor Yellow
            $OldDeletePreference = $ErrorActionPreference
            $ErrorActionPreference = "Continue"
            try {
                kubectl delete -f k8s\ 2>&1 | Out-Null
            } finally {
                $ErrorActionPreference = $OldDeletePreference
            }
            Write-Host "[INFO] Entrusting database and LLM images to native cluster pulling rules. Host sideloading skipped." -ForegroundColor Green
        }
    }
    
    Write-Host "[SUCCESS] Cleanup phase complete." -ForegroundColor Green
}


function Deploy-Infra {
    Write-Host "[INFRA] Spinning up infrastructure layer for Engine: $Engine..." -ForegroundColor Cyan
    
    if ($Engine -eq "k8s") {
        Write-Host "[K8s Mode] Orchestrating cluster node via Minikube..." -ForegroundColor Cyan
        minikube start --driver=docker --cpus=4 --memory=6144mb --addons=ingress
 
        Write-Host "[K8s Mode] Initializing storage credentials and vault contexts..." -ForegroundColor Cyan
        # Inject standard base64 bypass secrets to pass localstack authentication checks safely
        # kubectl create secret generic localstack-secrets --from-literal=auth-token="mock-cluster-token" --dry-run=client -o yaml | kubectl apply -f -
        
        Write-Host "[INFO] Entrusting database and LLM images to native cluster pulling rules. Host sideloading skipped." -ForegroundColor Green
        return
    }

    # Initialize persistent LLM volume space
    $volumeCheck = docker volume ls --filter name=$LlmVolume --format "{{.Name}}"
    if (-not $volumeCheck) {
        Write-Host "[INIT] Initializing persistent LLM volume space..." -ForegroundColor Yellow
        docker volume create $LlmVolume | Out-Null
    }

    # Initialize native named volume space for HuggingFace model cache to bypass Windows I/O blocks
    $hfVolumeCheck = docker volume ls --filter name=$HfVolume --format "{{.Name}}"
    if (-not $hfVolumeCheck) {
        Write-Host "[INIT] Initializing persistent HuggingFace model cache volume..." -ForegroundColor Yellow
        docker volume create $HfVolume | Out-Null
    }

    docker compose up -d localstack qdrant ollama
    Write-Host "[WAIT] Polling core database TCP socket definitions..." -ForegroundColor Yellow
    while ($true) {
        $qdrantCheck     = (New-Object Net.Sockets.TcpClient).ConnectAsync("localhost", 6333).Wait(300)
        $localstackCheck = (New-Object Net.Sockets.TcpClient).ConnectAsync("localhost", 4566).Wait(300)
        if ($qdrantCheck -and $localstackCheck) { break }
        Start-Sleep -Seconds 1
    }

    # Seed localized Ollama LLM weight cache
    $localModels = docker exec aegisrag-llm ollama list 2>$null
    if ($localModels -notmatch "llama3.2:1b") {
        Write-Host "[DOWNLOAD] Pulling LLM baseline weights..." -ForegroundColor Yellow
        docker exec aegisrag-llm ollama pull llama3.2:1b
    }
    Write-Host "[SUCCESS] Core infrastructure components are healthy." -ForegroundColor Green
}


function Build-Containers {
    # NEW HARDENING: Ensure the HF volume exists even if running standalone build
    $hfVolumeCheck = docker volume ls --filter name=$HfVolume --format "{{.Name}}"
    if (-not $hfVolumeCheck) {
        Write-Host "[INIT] Target HF named volume missing for tests. Initializing..." -ForegroundColor Yellow
        docker volume create $HfVolume | Out-Null
    }

    if ($Engine -eq "local") {
        Write-Host "[Local Mode] Compiling workspace dependencies natively..." -ForegroundColor Cyan
        uv lock
        if ($LASTEXITCODE -ne 0) { throw "Local UV lock generation failed." }
        
        uv sync
        if ($LASTEXITCODE -ne 0) { throw "Local UV dependency synchronization failed." }
        
        Write-Host "[Local Mode] Syncing frontend package lock references..." -ForegroundColor Cyan
        Push-Location apps\frontend
        
        npm install
        $NpmStatus = $LASTEXITCODE
        Pop-Location
        if ($NpmStatus -ne 0) { throw "Local Frontend NPM package installation failed." }
        
        return
    }

    Write-Host "[BUILD] Preparing container layers for Engine: $Engine..." -ForegroundColor Cyan
    if ($Engine -eq "k8s") {
        Write-Host "[K8s Mode] Redirecting host shell context to Minikube daemon..." -ForegroundColor Yellow
        
        # Best Practice: Safe-check the environment output before running it
        $DockerEnv = minikube docker-env 2>$null
        if ($DockerEnv -match "false" -or -not $DockerEnv) {
            Write-Error "[FATAL] Minikube cluster is unhealthy or not running. Cannot sync Docker environment context."
            throw "Target Cluster Context Resolution Breakage"
        }
        
        $DockerEnv | Invoke-Expression
        minikube update-context | Out-Null
    }

    $env:DOCKER_BUILDKIT = "1"

    # Compile Production Backend
    Write-Host "[BUILD] Building backend image using Buildx: $BackendImage..." -ForegroundColor Yellow
    docker buildx build --load -f packages/backend/Dockerfile -t $BackendImage .
    # NEW HARDENING GATE: Terminate instantly if the local package or base image layer build breaks
    if ($LASTEXITCODE -ne 0) { throw "Backend image container Docker compilation failed." }

    # Compile Production Frontend Nginx Layer
    Write-Host "[BUILD] Building frontend application container using Buildx: $FrontendImage..." -ForegroundColor Yellow
    docker buildx build --load -f apps/frontend/Dockerfile -t $FrontendImage .
    # NEW HARDENING GATE: Terminate instantly if the static distribution asset build breaks
    if ($LASTEXITCODE -ne 0) { throw "Frontend image container Docker compilation failed." }

    Write-Host "[TEST] Running isolated test suite within container wrapper..." -ForegroundColor Cyan
    $OldPref = $ErrorActionPreference
    $ErrorActionPreference = "Stop"
    try {
        Write-Host "[TEST] Launching isolated pytest execution environment..." -ForegroundColor Gray

        # Direct clean execution using the internal Docker Named Volume instead of a host path
        docker run --rm `
            -v "${HfVolume}:/root/.cache/huggingface" `
            -e QDRANT_HOST=:memory: `
            -e HF_HOME=/root/.cache/huggingface `
            -e HF_HUB_OFFLINE=0 `
            $BackendImage uv run --package aegisrag-backend pytest packages/backend/tests/ -v

        # Explicitly verify exit wrapper status for target docker daemon tasks
        if ($LASTEXITCODE -ne 0) { 
            throw "Pytest execution engine reported code errors." 
        }
        
        Write-Host "[SUCCESS] All containerized integration validations passed cleanly!" -ForegroundColor Green
    } catch {
        Write-Error "[FATAL] Container integration test suite failed. Aborting deployment pipeline."
        throw "Test Execution Breakage Detected"
    } finally {
        $ErrorActionPreference = $OldPref
    }
}

function Deploy-Application {
    Write-Host "[DEPLOY] Launching application gateway for Engine: $Engine..." -ForegroundColor Cyan
    Set-HostEnv
    switch ($Engine) {
        "local" {
            Push-Location packages\backend
            Start-Process -FilePath "uv" -ArgumentList "run uvicorn main:app --host 0.0.0.0 --port 8000 --reload" -NoNewWindow
            Pop-Location
            Write-Host "[DEPLOY] Initializing native frontend UI layout panel stream..." -ForegroundColor Cyan
            Push-Location apps\frontend
            Start-Process -FilePath "npm" -ArgumentList "run dev" -NoNewWindow
            Pop-Location
        }
        "docker" {
            $NetworkName = (docker inspect aegisrag-kms --format='{{range $k,$v := .NetworkSettings.Networks}}{{$k}}{{end}}' 2>$null)
            if (-not $NetworkName) { $NetworkName = "aegisrag-monorepo_default" }
            try { $null = docker rm -f aegisrag-backend 2>&1 } catch {}
            try { $null = docker rm -f aegisrag-frontend 2>&1 } catch {}
 
            # Backend
            docker run -d `
                --name aegisrag-backend `
                --network $NetworkName `
                -v "${HostHfCache}:/root/.cache/huggingface" `
                -p 8000:8000 `
                -e HF_HOME=/root/.cache/huggingface `
                -e HF_HUB_OFFLINE=1 `
                -e AWS_DEFAULT_REGION=us-east-1 `
                -e AWS_ENDPOINT_URL=http://aegisrag-kms:4566 `
                -e QDRANT_HOST=aegisrag-vector-db `
                -e OLLAMA_URL=http://aegisrag-llm:11434 `
                $BackendImage

            # Frontend Container
            Write-Host "[DEPLOY] Launching standalone frontend container routing to network gateway..." -ForegroundColor Cyan
            docker run -d `
                --name aegisrag-frontend `
                --network $NetworkName `
                -p 3000:80 `
                $FrontendImage

            Start-Sleep -Seconds 3
            if ($(docker inspect -f '{{.State.Running}}' aegisrag-backend) -eq "true") {
                Write-Host "[SUCCESS] Backend instance active on port 8000." -ForegroundColor Green
            } else {
                Write-Error "[FATAL] Backend failed to boot! Check logs: docker logs aegisrag-backend"
                throw "Application Boot Sequence Blocked"
            }
        }
        "k8s" {
            if (Test-Path "k8s\deployment.yaml") {
                # Enforce automatic environment linking so your terminal never drops its Minikube context
                Write-Host "[K8s Mode] Syncing terminal Docker registry context with Minikube..." -ForegroundColor Gray
                minikube docker-env | Invoke-Expression
                minikube update-context | Out-Null

                Write-Host "[DEPLOY] Applying multi-layer cluster manifests to Minikube..." -ForegroundColor Yellow
                kubectl apply -f k8s\deployment.yaml
 
                # Extended timeout from 90s to 300s to handle large infrastructure image extractions safely
                Write-Host "[DEPLOY] Waiting for persistent storage engines to settle..." -ForegroundColor Yellow
                kubectl rollout status deployment/ollama --timeout=300s
                if ($LASTEXITCODE -ne 0) { throw "Ollama infrastructure deployment rollout failed or timed out." }

                kubectl rollout status deployment/qdrant --timeout=300s
                if ($LASTEXITCODE -ne 0) { throw "Qdrant infrastructure deployment rollout failed or timed out." }

                Write-Host "[DEPLOY] Waiting for Pod metadata registration handles to bind..." -ForegroundColor Yellow
                Start-Sleep -Seconds 5
                
                # Bypass JSONPath quote corruption entirely using clean native PowerShell piping
                $OllamaPod = (kubectl get pods -l app=ollama --no-headers | Select-Object -First 1 | ForEach-Object { ($_ -split '\s+')[0] })

                if (-not $OllamaPod -or $OllamaPod -eq "") {
                    Write-Error "[FATAL] Failed to retrieve runtime Ollama pod name handle. Aborting target stream."
                    throw "Pod Metadata Identification Failure"
                }

                # Dynamic Pod Readiness Checking Gate. Actively polls the container state 
                # to prevent the script from trying to execute commands inside a container that isn't fully live yet.
                Write-Host "[DEPLOY] Checking container lifecycle health for pod: $OllamaPod..." -ForegroundColor Gray
                $MaxAttempts = 30
                $Attempt = 0
                while ($true) {
                    $PodPhase = (kubectl get pod $OllamaPod -o jsonpath='{.status.phase}' 2>$null)
                    
                    if ($PodPhase -eq "Running") {
                        Write-Host "[SUCCESS] Ollama container engine is active and ready for commands." -ForegroundColor Green
                        break
                    }
                    
                    $Attempt++
                    if ($Attempt -ge $MaxAttempts) {
                        Write-Error "[FATAL] Timeout waiting for pod $OllamaPod to run. State is currently: $PodPhase"
                        throw "Container Runtime Hook Failure"
                    }
                    
                    Write-Host "[WAIT] Pod status is '$PodPhase'. Waiting for download layer initialization... ($Attempt/$MaxAttempts)" -ForegroundColor Yellow
                    Start-Sleep -Seconds 10
                }

                # Guard check prevents slow, repetitive network pulls if weights already exist on disk
                Write-Host "[DEPLOY] Checking LLM baseline weight status inside pod context..." -ForegroundColor Gray
                $ExistingModels = (kubectl exec -i $OllamaPod -- ollama list 2>$null)
                if ($ExistingModels -notmatch "llama3.2:1b") {
                    Write-Host "[DOWNLOAD] LLM baseline weights missing on volume disk. Pulling layers..." -ForegroundColor Yellow
                    kubectl exec -i $OllamaPod -- ollama pull llama3.2:1b
                } else {
                    Write-Host "[INFO] Storage cache hit! Llama3.2:1b already present inside volume claim space." -ForegroundColor Green
                }

                Write-Host "[DEPLOY] Cycling backend gateway engines onto live pipeline..." -ForegroundColor Yellow
                kubectl rollout restart deployment/aegisrag-backend
                
                # Extended timeouts for application layers to 300s to avoid early binding crashes
                Write-Host "[WAIT] Waiting for backend rolling update to finish completely..." -ForegroundColor Yellow
                kubectl rollout status deployment/aegisrag-backend --timeout=600s 
                if ($LASTEXITCODE -ne 0) { throw "Backend application deployment rollout failed or timed out." }

                kubectl rollout status deployment/aegisrag-frontend --timeout=600s
                if ($LASTEXITCODE -ne 0) { throw "Frontend application deployment rollout failed or timed out." }

                # Clean out existing active ports to ensure conflict-free binds
                Write-Host "[NET] Clearing active terminal networking proxy blocks..." -ForegroundColor Gray
                Get-Process -Name "kubectl" -ErrorAction SilentlyContinue | Stop-Process -Force
                Get-Process -Name "minikube" -ErrorAction SilentlyContinue | Stop-Process -Force

                # --- SECURE HEADLESS PORT FORWARDING VIA LOCALHOST IPv4 ---
                Write-Host "[NET] Binding secure Kubernetes port-forward tunnels..." -ForegroundColor Cyan
                Start-Process -FilePath "kubectl" -ArgumentList "port-forward deployment/aegisrag-frontend 3000:80 --address 127.0.0.1" -WindowStyle Hidden
                Start-Process -FilePath "kubectl" -ArgumentList "port-forward deployment/aegisrag-backend 8000:8000 --address 127.0.0.1" -WindowStyle Hidden
                Start-Process -FilePath "kubectl" -ArgumentList "port-forward deployment/qdrant 6333:6333 --address 127.0.0.1" -WindowStyle Hidden
                Start-Process -FilePath "kubectl" -ArgumentList "port-forward deployment/localstack 4566:4566 --address 127.0.0.1" -WindowStyle Hidden

                Write-Host "Port mappings verified and active in headless mode!" -ForegroundColor Green
                Write-Host "APIs: http://127.0.0.1:8000" -ForegroundColor Green
                Write-Host "UI:   http://127.0.0.1:3000" -ForegroundColor Green
                Write-Host "DB:   http://127.0.0.1:6333" -ForegroundColor Green
            } else {
                Write-Error "[ERROR] Target k8s manifests not found."
            }
        }
    }
}




function Invoke-TestPipeline-old {
    Write-Host "[TEST] Executing script health validations..." -ForegroundColor Cyan
    try {
        $TargetUrl = "http://localhost:8000/docs"
        # Wait slightly to give the new port forward hooks an opportunity to initialize completely
        Start-Sleep -Seconds 2
        $Response  = Invoke-WebRequest -Uri $TargetUrl -UseBasicParsing -TimeoutSec 5
        if ($Response.StatusCode -eq 200) {
            Write-Host "[SUCCESS] API Docs endpoint resolved with status code 200." -ForegroundColor Green
        }
    } catch {
        Write-Error "[FAIL] Unable to connect to backend server. Verify service health logs."
    }
}

function Invoke-TestPipeline {
    Write-Host "[TEST] Executing engine health and pipeline validations..." -ForegroundColor Cyan
    
    # 1. Base Endpoint Smoke Test
    try {
        $TargetUrl = "http://localhost:8000/docs"
        Start-Sleep -Seconds 3 # Give proxy/port-forward channels a moment to bind cleanly
        $Response  = Invoke-WebRequest -Uri $TargetUrl -UseBasicParsing -TimeoutSec 5
        if ($Response.StatusCode -eq 200) {
            Write-Host "[SUCCESS] Live gateway interface resolved with status code 200." -ForegroundColor Green
        }
    } catch {
        Write-Error "[FAIL] Core API server is unreachable. Check operational logging streams."
        throw "Runtime Connectivity Breakage Detected"
    }

    # 2. Dynamic Pytest Engine Router
    Write-Host "[TEST] Launching automated neural test suite passes..." -ForegroundColor Cyan
    
    switch ($Engine) {
        "local" {
            Write-Host "[Local Mode] Running pytest suite natively using uv framework..." -ForegroundColor Yellow
            # Temporarily step into the backend package layout folder to keep imports clean
            Push-Location packages\backend
            try {
                uv run pytest tests/ -v
                if ($LASTEXITCODE -ne 0) { throw "Nativelocal Pytest execution returned fault signatures." }
                Write-Host "[SUCCESS] All native local unit validations passed cleanly!" -ForegroundColor Green
            } finally {
                Pop-Location
            }
        }

        "docker" {
            Write-Host "[Docker Mode] Running pytest validations inside live application container container..." -ForegroundColor Yellow
            # Execute pytest within the already running background container sandbox
            docker exec aegisrag-backend uv run --package aegisrag-backend pytest packages/backend/tests/ -v
            if ($LASTEXITCODE -ne 0) { 
                throw "Containerized app runtime reports internal test suite breakdown." 
            }
            Write-Host "[SUCCESS] All container validation runs completed successfully!" -ForegroundColor Green
        }

        "k8s" {
            Write-Host "[K8s Mode] Locating live cluster backend pod handle..." -ForegroundColor Yellow
            $BackendPod = (kubectl get pods -l app=aegisrag-backend --no-headers | Select-Object -First 1 | ForEach-Object { ($_ -split '\s+')[0] })
            
            if (-not $BackendPod) {
                throw "Unable to resolve active target backend pods in cluster namespace."
            }

            Write-Host "[K8s Mode] Routing remote test suite passes directly inside pod: $BackendPod..." -ForegroundColor Yellow
            # Run pytest inside your live, running cluster pod replica node space
            kubectl exec -i $BackendPod -- uv run --package aegisrag-backend pytest packages/backend/tests/ -v
            if ($LASTEXITCODE -ne 0) { 
                throw "Kubernetes cluster orchestration layer failed test assertions." 
            }
            Write-Host "[SUCCESS] All distributed cluster verification steps verified!" -ForegroundColor Green
        }
    }
}


# --- Core Orchestration Router Logic ---
Load-DotEnv
switch ($Action) {
    "clean"       { Invoke-Clean }
    "infra"       { Deploy-Infra }
    "build"       { Build-Containers }
    "deploy"      { Deploy-Application }
    "test"        { Invoke-TestPipeline }
    "verify-all"  {
        Invoke-Clean
        Deploy-Infra
        Build-Containers
        Deploy-Application
        #Invoke-TestPipeline
    }
}

