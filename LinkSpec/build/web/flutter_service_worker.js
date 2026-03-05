'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"assets/AssetManifest.bin": "b1fedea34b375675a28ce4a924a822d8",
"assets/AssetManifest.bin.json": "b03bfe3efba961c0fd0520d72811917b",
"assets/AssetManifest.json": "fb662c4304364c525837c28f605b811b",
"assets/assets/images/apply_wizz_logo.jpg": "1e702913f834fbcf611e955e0bdf8c47",
"assets/assets/svg/login_illustration.svg": "8c77d0bcb9bd206d7981ccc833ce8b4b",
"assets/assets/svg/marble_texture.svg": "31eabfc33e025ecaeb552d4344786dfd",
"assets/assets/svg/side_organic_curve.svg": "e586b629e5ebe0a138f7c7525933a93d",
"assets/assets/svg/soft_coral.svg": "9f66591250eff12d670ef80e5e37eec5",
"assets/assets/svg/soft_green_blob.svg": "952a66b1c957af93f6525e0ee69de9e1",
"assets/assets/svg/undraw_chatting_5u5z.svg": "f36fbca6bdd517d130ecf5aae65e921e",
"assets/assets/svg/undraw_coming-soon_7lvi.svg": "b2ed6dd43395bff6296dff217f6134d4",
"assets/assets/svg/undraw_followers_m4z4.svg": "a92cd4d16ebf7117e67383c3df3a72df",
"assets/assets/svg/undraw_login_weas.svg": "1a19b610198f158f5e3fe35c86853626",
"assets/assets/svg/undraw_love_9mug.svg": "d22a7a942f78588a3030585832e0fff6",
"assets/assets/svg/undraw_post_eok2.svg": "1c5e440bec3e0d5d762536c1dc7e2e34",
"assets/assets/svg/undraw_searching_no1g.svg": "ab3ff6c5ef3d14fd77ece47bac76ec15",
"assets/assets/svg/undraw_text-messages_978a.svg": "434ada5e8ca41044c4d8ab5219198c5d",
"assets/assets/svg/wired-outline-20-love-heart-hover-heartbeat.svg": "4bc484c69b5cdd00b728b0ad8d9dca2b",
"assets/assets/svg/wired-outline-259-share-arrow-hover-slide.svg": "8cb679a69d65ec2f1d5372b093287969",
"assets/assets/svg/wired-outline-981-consultation-hover-conversation-alt.svg": "f371742c126e9803f870dad26be27250",
"assets/FontManifest.json": "dc3d03800ccca4601324923c0b1d6d57",
"assets/fonts/MaterialIcons-Regular.otf": "0f3169efa2d1d32cd8126ad62e9cb004",
"assets/NOTICES": "cd6bbe2f8e47e6690ae76a66ef2daa15",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "e986ebe42ef785b27164c36a9abc7818",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"canvaskit/canvaskit.js": "26eef3024dbc64886b7f48e1b6fb05cf",
"canvaskit/canvaskit.js.symbols": "efc2cd87d1ff6c586b7d4c7083063a40",
"canvaskit/canvaskit.wasm": "e7602c687313cfac5f495c5eac2fb324",
"canvaskit/chromium/canvaskit.js": "b7ba6d908089f706772b2007c37e6da4",
"canvaskit/chromium/canvaskit.js.symbols": "e115ddcfad5f5b98a90e389433606502",
"canvaskit/chromium/canvaskit.wasm": "ea5ab288728f7200f398f60089048b48",
"canvaskit/skwasm.js": "ac0f73826b925320a1e9b0d3fd7da61c",
"canvaskit/skwasm.js.symbols": "96263e00e3c9bd9cd878ead867c04f3c",
"canvaskit/skwasm.wasm": "828c26a0b1cc8eb1adacbdd0c5e8bcfa",
"canvaskit/skwasm.worker.js": "89990e8c92bcb123999aa81f7e203b1c",
"flutter.js": "4b2350e14c6650ba82871f60906437ea",
"flutter_bootstrap.js": "a2f97ddcd8bf3d01974659a3a961c316",
"icons/apply_wizz_logo.jpg": "1e702913f834fbcf611e955e0bdf8c47",
"index.html": "e06b3301e94ecf011925755a6b15dd65",
"/": "e06b3301e94ecf011925755a6b15dd65",
"main.dart.js": "7911414a5aca3ba1b61bda8de51fcbb6",
"main.dart.js_1.part.js": "d959cfc498a53f633ba70a2f44997644",
"main.dart.js_2.part.js": "df7a601a42b9d1d8249445ca6f2e6d69",
"manifest.json": "c6b35bd7d5b09a2ffde04aba2d0e4b4e",
"version.json": "8bfaf4a55685eb8456ae7dc34dd62448"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
