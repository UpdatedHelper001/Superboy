# GitHub → Automatic Game Build → GitHub Pages

## One-time setup
1. Create a GitHub repository.
2. Upload/push all files in this package to the repository.
3. Keep the default branch named `main`.
4. In GitHub, open **Settings → Pages**.
5. Under **Build and deployment**, choose **GitHub Actions**.
6. Push a commit.

## What happens after every push
`main` push → GitHub Actions → validates files → copies the game into `dist/` → uploads the Pages artifact → deploys it.

The deployed URL is shown in the workflow run and under **Settings → Pages**.

## Asset workflow
Put new GLBs under `assets/glb/`, commit and push. The workflow automatically includes them in the deployed build.

The game has procedural fallbacks, so a missing GLB does not stop the page from loading.

## Recommended repository structure
```
.
├── .github/
│   └── workflows/
│       └── deploy.yml
├── assets/
│   └── glb/
├── game.js
├── index.html
├── style.css
├── README.md
└── STORY_SOURCE.txt
```

No Node.js/npm build is required for this version because the game is a static browser application. Three.js and GLTFLoader are loaded from jsDelivr.
