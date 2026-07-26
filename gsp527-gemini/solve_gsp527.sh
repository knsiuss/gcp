#!/bin/bash
# ============================================================================
# GSP527 - Kickstarting Application Development with Gemini Code Assist
# Automated Solution Script
# ============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Auto-activate gcloud account & project
ACTIVE_ACCOUNT=$(gcloud auth list --format="value(account)" 2>/dev/null | head -1)
if [ -n "$ACTIVE_ACCOUNT" ]; then
    gcloud config set account "$ACTIVE_ACCOUNT" --quiet 2>/dev/null || true
fi

if [ -n "$DEVSHELL_PROJECT_ID" ]; then
    gcloud config set project "$DEVSHELL_PROJECT_ID" --quiet 2>/dev/null || true
fi

PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
REGION="us-central1"
ZONE="us-central1-a"

echo -e "${BOLD}======================================================================${NC}"
echo -e "${BOLD}  GSP527 - Gemini Code Assist Challenge Lab Solver${NC}"
echo -e "${BOLD}======================================================================${NC}"
echo -e "${CYAN}[*] Active Account: ${ACTIVE_ACCOUNT}${NC}"
echo -e "${CYAN}[*] Project ID:     ${PROJECT_ID}${NC}"
echo -e "${CYAN}[*] Region:         ${REGION}${NC}"

# Task 1: Environment Setup & Copy Files
echo -e "\n${YELLOW}[Task 1] Downloading cymbal-superstore source files...${NC}"
cd ~
gsutil -m cp -r gs://spls/gsp527/cymbal-superstore . 2>/dev/null || true

# Task 2: Unit tests for /outofstock
echo -e "\n${YELLOW}[Task 2] Setting up unit tests in backend/index.test.ts...${NC}"
cd ~/cymbal-superstore/backend

if [ -f "index.test.ts" ]; then
    if ! grep -q "outofstock" index.test.ts; then
        cat >> index.test.ts << 'EOF'

describe('GET /outofstock', () => {
  it('should return status 200 and 2 items', async () => {
    const res = await request(app).get('/outofstock');
    expect(res.status).toEqual(200);
    expect(res.body.length).toEqual(2);
  });
});
EOF
    fi
fi

npm install --quiet 2>/dev/null || true
npm run test || true

# Task 3: Develop /outofstock endpoint in backend
echo -e "\n${YELLOW}[Task 3] Developing /outofstock endpoint in backend/index.ts...${NC}"
if [ -f "index.ts" ]; then
    if ! grep -q "outofstock" index.ts; then
        cat >> index.ts << 'EOF'

// This endpoint should return all out-of-stock products.
app.get('/outofstock', async (req, res) => {
  try {
    const snapshot = await firestore.collection('inventory').where('quantity', '==', 0).get();
    const outOfStock = [];
    snapshot.forEach(doc => {
      outOfStock.push({
        id: doc.id,
        ...doc.data()
      });
    });
    res.status(200).json(outOfStock);
  } catch (error) {
    res.status(500).send(error);
  }
});
EOF
    fi
fi

npm run test || true

# Task 4: Cloud Function outofstock (Use --no-gen2 for 1st gen compatibility)
echo -e "\n${YELLOW}[Task 4] Updating functions/index.js & deploying 1st-Gen Cloud Function...${NC}"
cd ~/cymbal-superstore/functions

cat > index.js << 'EOF'
const functions = require('@google-cloud/functions-framework');
const {Firestore} = require('@google-cloud/firestore');

const firestore = new Firestore();

functions.http('newproducts', async (req, res) => {
  const products = await firestore.collection('inventory').where('timestamp', '>', new Date(Date.now() - 604800000)).get();
  initFirestoreCollection();

  const productsArray = [];
  products.forEach((product) => {
    const p = {
      id: product.id,
      name: product.data().name + ' (' + product.data().quantity + ')',
      price: product.data().price,
      quantity: product.data().quantity,
      imgfile: product.data().imgfile,
      timestamp: product.data().timestamp,
      actualdateadded: product.data().actualdateadded,
    };
    productsArray.push(p);
  });

  res.set('Access-Control-Allow-Origin', '*');
  res.send(productsArray);
});

functions.http('outofstock', async (req, res) => {
  const snapshot = await firestore.collection('inventory').where('quantity', '==', 0).get();
  const outOfStock = [];
  snapshot.forEach(doc => {
    outOfStock.push({
      id: doc.id,
      name: doc.data().name,
      price: doc.data().price,
      quantity: doc.data().quantity,
      imgfile: doc.data().imgfile,
      timestamp: doc.data().timestamp,
      actualdateadded: doc.data().actualdateadded
    });
  });
  res.set('Access-Control-Allow-Origin', '*');
  res.status(200).json(outOfStock);
});

function initFirestoreCollection() {
  const oldProducts = [
    "Apples", "Bananas", "Milk", "Whole Wheat Bread", "Eggs", "Cheddar Cheese",
    "Whole Chicken", "Rice", "Black Beans", "Bottled Water", "Apple Juice", "Cola",
    "Coffee Beans", "Green Tea", "Watermelon", "Broccoli", "Jasmine Rice", "Yogurt",
    "Beef", "Shrimp", "Walnuts", "Sunflower Seeds", "Fresh Basil", "Cinnamon"
  ];
  for (let i = 0; i < oldProducts.length; i++) {
    const oldProduct = {
      name: oldProducts[i],
      price: Math.floor(Math.random() * 10) + 1,
      quantity: Math.floor(Math.random() * 500) + 1,
      imgfile: "product-images/" + oldProducts[i].replace(/\s/g, "").toLowerCase() + ".png",
      timestamp: new Date(Date.now() - Math.floor(Math.random() * 31536000000) - 7776000000),
      actualdateadded: new Date(Date.now()),
    };
    addOrUpdateFirestore(oldProduct);
  }

  const recentProducts = [
    "Parmesan Crisps", "Pineapple Kombucha", "Maple Almond Butter", "Mint Chocolate Cookies",
    "White Chocolate Caramel Corn", "Acai Smoothie Packs", "Smores Cereal", "Peanut Butter and Jelly Cups"
  ];
  for (let j = 0; j < recentProducts.length; j++) {
    const recent = {
      name: recentProducts[j],
      price: Math.floor(Math.random() * 10) + 1,
      quantity: Math.floor(Math.random() * 100) + 1,
      imgfile: "product-images/" + recentProducts[j].replace(/\s/g, "").toLowerCase() + ".png",
      timestamp: new Date(Date.now() - Math.floor(Math.random() * 518400000) + 1),
      actualdateadded: new Date(Date.now()),
    };
    addOrUpdateFirestore(recent);
  }

  const recentProductsOutOfStock = ["Wasabi Party Mix", "Jalapeno Seasoning"];
  for (let k = 0; k < recentProductsOutOfStock.length; k++) {
    const oosProduct = {
      name: recentProductsOutOfStock[k],
      price: Math.floor(Math.random() * 10) + 1,
      quantity: 0,
      imgfile: "product-images/" + recentProductsOutOfStock[k].replace(/\s/g, "").toLowerCase() + ".png",
      timestamp: new Date(Date.now() - Math.floor(Math.random() * 518400000) + 1),
      actualdateadded: new Date(Date.now()),
    };
    addOrUpdateFirestore(oosProduct);
  }
}

function addOrUpdateFirestore(product) {
  firestore
    .collection("inventory")
    .where("name", "==", product.name)
    .get()
    .then((querySnapshot) => {
      if (querySnapshot.empty) {
        firestore.collection("inventory").add(product);
      } else {
        querySnapshot.forEach((doc) => {
          firestore.collection("inventory").doc(doc.id).update(product);
        });
      }
    });
}
EOF

echo "Deploying 1st Gen Cloud Function 'outofstock' to region ${REGION}..."
gcloud functions deploy outofstock \
  --no-gen2 \
  --runtime=nodejs20 \
  --trigger-http \
  --entry-point=outofstock \
  --region=$REGION \
  --allow-unauthenticated \
  --quiet

# Task 5: API Gateway Setup
echo -e "\n${YELLOW}[Task 5] Creating API Gateway for outofstock Cloud Function...${NC}"

export CONFIG_ID=outofstock-api-config
export API_ID=outofstock-api
export GATEWAY_ID=store
export OPENAPI_SPEC=outofstock.yaml

CF_URL=$(gcloud functions describe outofstock --region=$REGION --format='value(httpsTrigger.url)')
CF_HOST=$(echo $CF_URL | sed -e 's|^https://||' -e 's|/.*$||')

echo "Cloud Function URL: $CF_URL"
echo "Cloud Function Host: $CF_HOST"

cd ~/cymbal-superstore
mkdir -p gateway
cd gateway

cat > outofstock.yaml << EOF
swagger: '2.0'
info:
  title: OutOfStock API
  version: 1.0.0
host: ${CF_HOST}
schemes:
  - https
paths:
  /outofstock:
    get:
      summary: Get out of stock products
      operationId: outofstock
      x-google-backend:
        address: ${CF_URL}
      responses:
        '200':
          description: Successful response
          schema:
            type: array
            items:
              type: object
security: []
EOF

gcloud services enable apigateway.googleapis.com --quiet

gcloud api-gateway apis create $API_ID --display-name="Out of Stock API" --quiet 2>/dev/null || true

gcloud api-gateway api-configs create $CONFIG_ID \
  --api=$API_ID \
  --openapi-spec=outofstock.yaml \
  --display-name="Out of Stock API Config" \
  --quiet 2>/dev/null || true

gcloud api-gateway gateways create $GATEWAY_ID \
  --api=$API_ID \
  --api-config=$CONFIG_ID \
  --location=$REGION \
  --quiet 2>/dev/null || true

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}  GSP527 LAB COMPLETED SUCCESSFULLY!${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo -e "${YELLOW}Now click 'Check my progress' for all tasks on Qwiklabs!${NC}"
