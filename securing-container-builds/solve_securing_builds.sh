#!/bin/bash
# solve_securing_builds.sh
# Automating Securing Container Builds (GSP1185)

set -e

# Colors for terminal output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}======================================================================${NC}"
echo -e "${BLUE}        Automated Solver: Securing Container Builds (GSP1185)         ${NC}"
echo -e "${BLUE}======================================================================${NC}"

# Detect GCP Project details
export PROJECT_ID=$(gcloud config get-value project)
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')

echo -e "${YELLOW}[*] Project ID:${NC} $PROJECT_ID"
echo -e "${YELLOW}[*] Project Number:${NC} $PROJECT_NUMBER"

echo -e "\n${YELLOW}[Step 1] Enabling Artifact Registry API...${NC}"
gcloud services enable artifactregistry.googleapis.com

echo -e "\n${YELLOW}[Step 2] Cloning java-docs-samples repo...${NC}"
git clone https://github.com/GoogleCloudPlatform/java-docs-samples || true
cd java-docs-samples/container-registry/container-analysis

echo -e "\n${YELLOW}[Step 3] Task 1: Creating Standard Maven Repository...${NC}"
gcloud artifacts repositories create container-dev-java-repo \
    --repository-format=maven \
    --location=us-central1 \
    --description="Java package repository for Container Dev Workshop" || true

echo -e "${GREEN}[+] Standard Repository created! (Please check progress on Qwiklabs)${NC}"

echo -e "\n${YELLOW}[Step 4] Task 2: Configuring Maven for Artifact Registry...${NC}"
# Patch pom.xml to bypass wrong local parent POM lookup by adding relativePath tag
python3 -c "
with open('pom.xml', 'r') as f:
    content = f.read()

target = '''  <parent>
    <groupId>com.google.cloud.samples</groupId>
    <artifactId>shared-configuration</artifactId>
    <version>1.2.0</version>
  </parent>'''

replacement = '''  <parent>
    <groupId>com.google.cloud.samples</groupId>
    <artifactId>shared-configuration</artifactId>
    <version>1.2.0</version>
    <relativePath/>
  </parent>'''

if target in content:
    content = content.replace(target, replacement)
    print('Parent POM patched with empty relativePath!')
else:
    # Fallback to general replace
    content = content.replace('<version>1.2.0</version>', '<version>1.2.0</version>\\n    <relativePath/>')
    print('Parent POM version patched with relativePath!')

with open('pom.xml', 'w') as f:
    f.write(content)
"

# Use Python to modify pom.xml to add distributionManagement, repositories and Wagon extension before </project>
python3 -c "
import sys
project_id = sys.argv[1]

with open('pom.xml', 'r') as f:
    pom = f.read()

# Config block to insert
config = f'''
  <distributionManagement>
    <snapshotRepository>
      <id>artifact-registry</id>
      <url>artifactregistry://us-central1-maven.pkg.dev/{project_id}/container-dev-java-repo</url>
    </snapshotRepository>
    <repository>
      <id>artifact-registry</id>
      <url>artifactregistry://us-central1-maven.pkg.dev/{project_id}/container-dev-java-repo</url>
    </repository>
  </distributionManagement>

  <repositories>
    <repository>
      <id>artifact-registry</id>
      <url>artifactregistry://us-central1-maven.pkg.dev/{project_id}/container-dev-java-repo</url>
      <releases>
        <enabled>true</enabled>
      </releases>
      <snapshots>
        <enabled>true</enabled>
      </snapshots>
    </repository>
  </repositories>

  <build>
    <extensions>
      <extension>
        <groupId>com.google.cloud.artifactregistry</groupId>
        <artifactId>artifactregistry-maven-wagon</artifactId>
        <version>2.2.0</version>
      </extension>
    </extensions>
  </build>
'''

# Insert before </project>
pom = pom.replace('</project>', config + '\n</project>')

with open('pom.xml', 'w') as f:
    f.write(pom)
" "$PROJECT_ID"

echo -e "${YELLOW}[*] Deploying package to Artifact Registry...${NC}"
mvn deploy -DskipTests


echo -e "${GREEN}[+] Package deployed successfully!${NC}"

echo -e "\n${YELLOW}[Step 5] Task 3: Creating Remote Maven Central Cache...${NC}"
gcloud artifacts repositories create maven-central-cache \
    --project=\$PROJECT_ID \
    --repository-format=maven \
    --location=us-central1 \
    --description="Remote repository for Maven Central caching" \
    --mode=remote-repository \
    --remote-repo-config-desc="Maven Central" \
    --remote-mvn-repo=MAVEN-CENTRAL || true

echo -e "${GREEN}[+] Remote Repository created! (Please check progress on Qwiklabs)${NC}"

echo -e "\n${YELLOW}[Step 6] Configuring central repository cache in pom.xml...${NC}"
# Use Python to add the central cache repository to the repositories list
python3 -c "
import sys
project_id = sys.argv[1]

with open('pom.xml', 'r') as f:
    pom = f.read()

old_repos = f'''  <repositories>
    <repository>
      <id>artifact-registry</id>
      <url>artifactregistry://us-central1-maven.pkg.dev/{project_id}/container-dev-java-repo</url>
      <releases>
        <enabled>true</enabled>
      </releases>
      <snapshots>
        <enabled>true</enabled>
      </snapshots>
    </repository>
  </repositories>'''

new_repos = f'''  <repositories>
    <repository>
      <id>artifact-registry</id>
      <url>artifactregistry://us-central1-maven.pkg.dev/{project_id}/container-dev-java-repo</url>
      <releases>
        <enabled>true</enabled>
      </releases>
      <snapshots>
        <enabled>true</enabled>
      </snapshots>
    </repository>

    <repository>
      <id>central</id>
      <url>artifactregistry://us-central1-maven.pkg.dev/{project_id}/maven-central-cache</url>
      <releases>
        <enabled>true</enabled>
      </releases>
      <snapshots>
        <enabled>true</enabled>
      </snapshots>
    </repository>
  </repositories>'''

pom = pom.replace(old_repos, new_repos)

with open('pom.xml', 'w') as f:
    f.write(pom)
" "$PROJECT_ID"

echo -e "${YELLOW}[*] Creating extensions.xml...${NC}"
mkdir -p .mvn 
cat > .mvn/extensions.xml << EOF
<extensions xmlns="http://maven.apache.org/EXTENSIONS/1.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://maven.apache.org/EXTENSIONS/1.0.0 http://maven.apache.org/xsd/core-extensions-1.0.0.xsd">
  <extension>
    <groupId>com.google.cloud.artifactregistry</groupId>
    <artifactId>artifactregistry-maven-wagon</artifactId>
    <version>2.2.0</version>
  </extension>
</extensions>
EOF

echo -e "${YELLOW}[*] Compiling using Remote central cache...${NC}"
rm -rf ~/.m2/repository 
mvn compile

echo -e "${GREEN}[+] Maven compilation complete! Central packages cached.${NC}"

echo -e "\n${YELLOW}[Step 7] Task 4: Setting up Virtual Repository...${NC}"
cat > ./policy.json << EOF
[
  {
    "id": "private",
    "repository": "projects/${PROJECT_ID}/locations/us-central1/repositories/container-dev-java-repo",
    "priority": 100
  },
  {
    "id": "central",
    "repository": "projects/${PROJECT_ID}/locations/us-central1/repositories/maven-central-cache",
    "priority": 80
  }
]
EOF

gcloud artifacts repositories create virtual-maven-repo \
    --project=\${PROJECT_ID} \
    --repository-format=maven \
    --mode=virtual-repository \
    --location=us-central1 \
    --description="Virtual Maven Repo" \
    --upstream-policy-file=./policy.json || true

echo -e "${GREEN}[+] Virtual Repository created! (Please check progress on Qwiklabs)${NC}"

echo -e "\n${YELLOW}[Step 8] Configuring pom.xml to pull from Virtual Repository...${NC}"
# Use Python to modify pom.xml to replace the repositories block with a single point to virtual-maven-repo
python3 -c "
import sys
project_id = sys.argv[1]

with open('pom.xml', 'r') as f:
    pom = f.read()

old_repos = f'''  <repositories>
    <repository>
      <id>artifact-registry</id>
      <url>artifactregistry://us-central1-maven.pkg.dev/{project_id}/container-dev-java-repo</url>
      <releases>
        <enabled>true</enabled>
      </releases>
      <snapshots>
        <enabled>true</enabled>
      </snapshots>
    </repository>

    <repository>
      <id>central</id>
      <url>artifactregistry://us-central1-maven.pkg.dev/{project_id}/maven-central-cache</url>
      <releases>
        <enabled>true</enabled>
      </releases>
      <snapshots>
        <enabled>true</enabled>
      </snapshots>
    </repository>
  </repositories>'''

new_repos = f'''  <repositories>
    <repository>
      <id>artifact-registry</id>
      <url>artifactregistry://us-central1-maven.pkg.dev/{project_id}/virtual-maven-repo</url>
      <releases>
        <enabled>true</enabled>
      </releases>
      <snapshots>
        <enabled>true</enabled>
      </snapshots>
    </repository>
  </repositories>'''

pom = pom.replace(old_repos, new_repos)

with open('pom.xml', 'w') as f:
    f.write(pom)
" "$PROJECT_ID"

echo -e "${YELLOW}[*] Deleting and recreating central cache repo to empty cache...${NC}"
gcloud artifacts repositories delete maven-central-cache \
    --project=\$PROJECT_ID \
    --location=us-central1 \
    --quiet

gcloud artifacts repositories create maven-central-cache \
    --project=\$PROJECT_ID \
    --repository-format=maven \
    --location=us-central1 \
    --description="Remote repository for Maven Central caching" \
    --mode=remote-repository \
    --remote-repo-config-desc="Maven Central" \
    --remote-mvn-repo=MAVEN-CENTRAL

echo -e "${YELLOW}[*] Compiling using Virtual repository...${NC}"
rm -rf ~/.m2/repository 
mvn compile

echo -e "${GREEN}======================================================================${NC}"
echo -e "${GREEN}    Artifact Registry Lab completed successfully! Check Qwiklabs progress.${NC}"
echo -e "${GREEN}======================================================================${NC}"
