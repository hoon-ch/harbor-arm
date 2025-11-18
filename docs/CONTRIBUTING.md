# Contributing to Harbor ARM64

Thank you for your interest in contributing to Harbor ARM64!

## Ways to Contribute

### 1. Report Issues

If you encounter any problems:

- Check existing issues first to avoid duplicates
- Provide detailed information:
  - Harbor version
  - Component that failed
  - Build logs or error messages
  - Your environment (OS, Docker version, etc.)

### 2. Improve Documentation

- Fix typos or clarify instructions
- Add examples or use cases
- Translate documentation

### 3. Enhance Build Scripts

- Optimize build process
- Add support for more platforms
- Improve error handling

### 4. Add Features

- Support for additional registries
- Build optimization
- Testing improvements

## Development Setup

### Prerequisites

```bash
# Install Docker with Buildx
docker --version
docker buildx version

# Setup QEMU for ARM emulation (if on x86_64)
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
```

### Local Testing

1. Fork the repository
2. Clone your fork
3. Make changes
4. Test locally:

```bash
# Test build script
./scripts/build-local.sh v2.11.0

# Test a specific component
cd harbor/make/photon/core
docker buildx build --platform linux/arm64 -f Dockerfile .
```

## Pull Request Process

1. **Create a Branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make Changes**
   - Follow existing code style
   - Update documentation if needed
   - Test your changes

3. **Commit**
   ```bash
   git add .
   git commit -m "Description of changes"
   ```

4. **Push and Create PR**
   ```bash
   git push origin feature/your-feature-name
   ```
   - Create a Pull Request on GitHub
   - Describe your changes clearly
   - Link related issues if any

## Code Style

### Shell Scripts

- Use `#!/bin/bash` shebang
- Use `set -e` for error handling
- Add comments for complex logic
- Use meaningful variable names
- Quote variables: `"$VARIABLE"`

### GitHub Actions

- Use descriptive job and step names
- Add comments for complex workflows
- Use official actions when possible
- Pin action versions (e.g., `@v4`)

## Testing

Before submitting a PR:

1. **Test build scripts**:
   ```bash
   ./scripts/build-local.sh
   ```

2. **Verify GitHub Actions workflow**:
   - Check syntax with yamllint or similar tools
   - Test workflow manually if possible

3. **Documentation**:
   - Ensure README is up to date
   - Check for broken links
   - Verify examples work

## Questions?

- Open an issue for questions
- Tag issues with appropriate labels
- Be patient and respectful

## License

By contributing, you agree that your contributions will be licensed under the same license as the project.
