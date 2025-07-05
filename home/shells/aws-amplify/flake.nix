{
  description = "AWS Amplify Gen 2 development environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          name = "aws-amplify-dev";
          
          buildInputs = with pkgs; [
            # Node.js and package managers
            nodejs_20
            yarn
            pnpm
            
            # AWS CLI and tools
            awscli2
            aws-cdk
            
            # TypeScript and development tools
            typescript
            nodePackages.typescript-language-server
            nodePackages.eslint
            nodePackages.prettier
            
            # Git and development utilities
            git
            jq
            curl
            
            # System dependencies
            python3
            gcc
            gnumake
            
            # Docker for local testing
            docker
            docker-compose
          ];
          
          shellHook = ''
            echo "AWS Amplify Gen 2 Development Environment"
            echo "========================================="
            echo "Node.js version: $(node --version)"
            echo "NPM version: $(npm --version)"
            echo "AWS CLI version: $(aws --version)"
            echo ""
            echo "Available commands:"
            echo "  npm install         - Install dependencies"
            echo "  npm run build       - Build the project"
            echo "  npm run deploy      - Deploy to AWS"
            echo "  npm run test        - Run tests"
            echo "  npm run lint        - Run linting"
            echo ""
            echo "Make sure to configure AWS credentials:"
            echo "  aws configure"
            echo ""
            
            # Set up local development environment
            export NODE_ENV=development
            export AWS_REGION=us-east-1
            
            # Create directories for development
            mkdir -p .amplify
            mkdir -p dist
            mkdir -p logs
            
            # Install dependencies if package.json exists
            if [ -f package.json ]; then
              echo "Installing dependencies..."
              npm install
            fi
          '';
          
          # Environment variables
          NODE_ENV = "development";
          AWS_REGION = "us-east-1";
          
          # Prevent npm from using system directories
          HOME = "$PWD/.nix-shell-home";
          
          # Configure npm to use local directory
          NPM_CONFIG_PREFIX = "$PWD/.npm-global";
          PATH = "$PWD/.npm-global/bin:$PATH";
        };
      });
}