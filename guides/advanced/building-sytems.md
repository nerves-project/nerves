# Building Nerves Systems with the `nerves_systems` Repository

This guide provides instructions for building custom Nerves systems using the [`nerves_systems`](https://github.com/nerves-project/nerves_systems) repository.

The `nerves_systems` repository offers an alternative way to build Nerves systems, designed for scenarios where the standard `mix`-based approach may be slower, such as when working extensively with Buildroot or maintaining multiple systems. While this method is faster and more efficient, it requires some setup and familiarity with system configuration and build processes.

By following this guide, you’ll gain the ability to create and customize Nerves systems for your hardware platform, contributing valuable improvements to the Nerves community.

---

## Prerequisites

The `nerves_systems` build process only works on **Linux** systems with `x86_64` or `aarch64` architectures. Non-Linux users must set up a Linux environment, such as a virtual machine (VM) or a container.

### General Requirements

- Basic familiarity with the Nerves project and embedded systems development.
- Access to a Linux environment:
  - **Native Linux Machine**: Best for performance and simplicity.
  - **macOS Users**: Install a Linux VM (e.g., via [UTM](https://mac.getutm.app)) to create an Ubuntu environment.
  - **Windows Users**: Use [WSL2](https://learn.microsoft.com/en-us/windows/wsl/install) with an Ubuntu distribution.
- At least **128GB of free disk space**: Building Nerves systems can require significant disk space, depending on the components included in the system.

### Linux Environment Requirements

Install the following packages in your Linux environment:

```bash
sudo apt update && sudo apt install -y git build-essential bc cmake cvs wget curl mercurial python3 python3-aiohttp python3-flake8 python3-ijson python3-nose2 python3-pexpect python3-pip python3-requests rsync subversion unzip gawk jq squashfs-tools libssl-dev automake autoconf libncurses5-dev
```

> #### Why These Packages? {: .info}
>
> These packages provide essential tools and libraries required for the Buildroot environment and system customization.

> #### Compatibility Note {: .info}
>
> This command is compatible with Debian 11 and 12, and Ubuntu 20.04, 22.04. Older distributions may require adjustments.

### macOS Setup

- Install [UTM](https://mac.getutm.app) to set up a Linux VM.
- Follow the Linux Environment Requirements above inside the VM.

### Windows Setup

- Install [WSL2](https://learn.microsoft.com/en-us/windows/wsl/install).
- Set up an Ubuntu distribution and follow the Linux Environment Requirements above within WSL2.

### Install Erlang and Elixir

If you've already followed the [Nerves Installation guide](https://hexdocs.pm/nerves/installation.html), Erlang and Elixir should be installed on your system. If not, refer to the installation instructions provided in the guide for your operating system.

### Install Nerves Archives

If you've completed the [Nerves Installation guide](https://hexdocs.pm/nerves/installation.html), the Nerves bootstrap archive and local rebar should already be set up. If not, you can install them with:

```bash
mix archive.install hex nerves_bootstrap
mix local.rebar
```

### Cloning the `nerves_systems` Repository

To begin working with Nerves systems, you’ll need to clone the `nerves_systems` repository from GitHub. This repository contains the necessary scripts and configurations for building and maintaining custom Nerves systems.

```bash
  git clone https://github.com/nerves-project/nerves_systems.git
  cd nerves_systems
```

---

## Step 1: Configuring the Build Environment

### Copy the Starter Configuration

To begin configuring the environment for building Nerves systems, you need to create a configuration file. This file specifies which systems to build. Use the provided starter configuration as a template:

```bash
cp config/starter-config.exs config/config.exs
```

The `starter-config.exs` file includes example configurations for common hardware platforms.

### Modify the Configuration File

Open the newly created `config/config.exs` file in a text editor. Review the listed systems and customize the configuration to include only the systems you want to build. For example:

### Download the Necessary Systems

After finalizing the configuration file, use the `ns.clone` mix task to download the repositories for the specified systems into the `src` directory. This command automates the cloning process:

```bash
mix ns.clone
```

The directory structure after running the command will look something like this:

```
src/
    nerves_system_br
    nerves_system_rpi0
    nerves_system_rpi3
    nerves_system_bbb
    ...
```

> #### Tip {: .tip}
>
> If you prefer, you can manually clone individual repositories into the `src` directory using `git clone`. Ensure the directory structure matches the above example.

> #### Resetting the Environment {: .info}
>
> If you need to start over or clean the environment:
>
> - Delete the `src` directory:
>   ```bash
>   rm -rf src
>   ```
> - Adjust your `config/config.exs` file as needed and rerun the `mix ns.clone` task.

---

## Step 2: Building Your Nerves Systems

The `nerves_systems` repository simplifies building custom systems by automating most of the setup. Follow these steps to build your systems:

### 1. Start the Build Process

Run the `ns.build` Mix task to build all systems listed in your configuration file. This task generates Buildroot `.config` files and compiles the systems.

```bash
mix ns.build
```

> #### What Happens During the Build? {: .info}
>
> - `.config` files are generated from `nerves_defconfig`.
> - The Buildroot process compiles the system for each target.

### 2. Check Build Output

Once the build completes, system outputs will be located in the `o/` directory. For example:

```plaintext
o/
  rpi0/
  rpi3/
  bbb/
```

Each directory contains:

- `.config`: The Buildroot configuration file.
- `build/`: Compiled binaries and intermediate files.
- `nerves.env.sh`: Script for setting environment variables.

> #### Quick Verification {: .tip}
>
> Run `ls o/<system name>` to confirm the build output exists (e.g., `ls o/rpi0`).

### 3. Handle Build Failures

If the `ns.build` task fails, use the following steps to debug:

1. **Locate the Failing System**:
   Navigate to the output directory of the system that failed:

   ```bash
   cd o/<system name>
   ```

2. **Rebuild Manually**:
   Run the Buildroot `make` process to identify issues:

   ```bash
   make
   ```

3. **Review Logs**:
   Examine error messages or logs for missing dependencies or configuration issues.

> #### Common Issues {: .warning}
>
> - Missing system dependencies: Ensure all required packages are installed.
> - Insufficient resources: Verify available disk space and memory.
> - Configuration errors: Check the `.config` file for misconfigurations.

### 4. Retry a Clean Build

If issues persist, clean the system's output directory and rebuild:

```bash
rm -rf o/<system name>
mix ns.build
```

> #### Why Clean Builds? {: .info}
>
> Cleaning removes corrupted or incomplete files, ensuring the build starts from a fresh state.

### 5. (Optional) Preload Build Dependencies

To speed up builds, you can preload dependencies for a system by running:

```bash
cd o/<system name>
make source
```

This downloads all required files in advance, making subsequent builds faster.

> #### When to Preload? {: .tip}
>
> - For systems with frequent reconfigurations.
> - When working offline or on slower networks.

---

## Step 3: Using Your Custom Nerves System

After successfully building the Nerves system, you need to set up your environment to use it in your Nerves project. This involves loading environment variables and specifying the target system for your project.

1. **Source the Environment Script**

   Each built system includes a `nerves.env.sh` script in the corresponding output directory (e.g., `o/rpi0/nerves.env.sh`). This script sets the necessary environment variables for your custom-built system.

   Open a new terminal session dedicated to working with your custom-built system, and source the script:

   ```bash
   . ~/path/to/nerves_systems/o/rpi0/nerves.env.sh
   ```

   Replace `rpi0` with the short name of your target system (e.g., `rpi3`, `bbb`) and adjust the path as needed.

   > #### Warning {: .warning}
   >
   > Each time you start a new terminal session for your Nerves project, you must source the script again to ensure the custom-built system is correctly configured.

2. **Set the Target System**
   Nerves uses the `MIX_TARGET` environment variable to identify the hardware target for your project. Set this variable to the short name of your target system. For example:

   ```bash
   export MIX_TARGET=rpi0
   ```

3. **Build Your Nerves Project**
   Navigate to your Nerves project directory and build it using `mix`. The environment variables and target settings will ensure that the project uses your custom-built Nerves system:

   ```bash
   mix deps.get
   mix firmware
   ```

4. **Verify the Custom System is in Use**
   Check that your project is using the custom-built system by running:

   ```bash
   mix nerves.info
   ```

   Look for the output indicating that the system is being sourced from your custom-built location (e.g., `o/rpi0`).

   > #### Troubleshooting {: .tip}
   >
   > - If the custom-built system isn’t being used, double-check that:
   >   - The `nerves.env.sh` script was sourced correctly.
   >   - The `MIX_TARGET` environment variable matches your intended target system.
   > - Verify the `o/<system short name>` directory contains the required build artifacts.

---

## Step 4: Customizing the Build (Optional)

Customizing your Nerves system is an advanced but powerful way to tailor the system to your needs. For comprehensive details on customizing systems, refer to the official [Customizing Your Nerves System](https://hexdocs.pm/nerves/customizing-systems.html) document. This guide provides deeper insights into topics such as Buildroot configurations, kernel adjustments, and integrating additional features.

Customizing the build allows you to tailor the Nerves system to meet specific requirements for your hardware or application. This involves modifying Buildroot configurations and applying changes to the Nerves system.

### Modify Buildroot Configuration

Nerves systems use Buildroot for building firmware. The `make menuconfig` command opens a menu-based interface where you can modify the Buildroot configuration:

```bash
cd o/<system short name>
make menuconfig
```

In this interface, you can:

- Add or remove packages.
- Configure kernel options.
- Set custom build flags.

> #### Tip {: .tip}
>
> Only make changes you understand, as incorrect settings may cause build failures or unstable firmware. For more details on Buildroot configuration, refer to the [Buildroot user manual](https://buildroot.org/downloads/manual/manual.html).

### Save the Updated Configuration

After making changes in `menuconfig`, save the configuration back to the system’s default configuration file (`nerves_defconfig`) using:

```bash
make savedefconfig
```

This ensures that your changes are preserved in the Buildroot configuration and can be reused in future builds. Learn more about Nerves system configuration in the [Nerves documentation](https://hexdocs.pm/nerves/systems.html).

### Rebuild the System

To apply your changes, clean the output directory for the system and rebuild:

```bash
rm -rf o/<system short name>
mix ns.build
```

This ensures a fresh build with your updated configuration.

### Make Additional Modifications (Optional)

You can further customize the Nerves system by modifying other configuration files, such as:

- **Linux kernel configuration:** Located in the Buildroot environment.
- **System files:** Add or update scripts, binaries, or other files required by your application.

To dive deeper into kernel customization, see the [Linux Kernel Documentation](https://www.kernel.org/doc/html/latest/).

### Test the Custom Build

After rebuilding, test the custom firmware on your hardware to ensure it meets your requirements. If issues arise:

- Review the Buildroot logs in `o/<system short name>/build/`.
- Iterate on the configuration as needed.

### Version Control Your Changes
 
If your customizations are for long-term use, consider committing your changes to version control. This is especially useful for:

- Collaborating with other developers.
- Reproducing builds in the future.

Example:

```bash
git add config/nerves_defconfig
git commit -m "Customize Buildroot configuration for <system name>"
```
