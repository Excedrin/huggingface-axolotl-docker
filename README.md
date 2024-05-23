---
title: Jupyter Axolotl
emoji: 💻🐳
colorFrom: gray
colorTo: green
sdk: docker
pinned: false
tags:
- jupyterlab
suggested_storage: small
license: apache-2.0
---

Check out the configuration reference at https://huggingface.co/docs/hub/spaces-config-reference

# Jupyter Axolotl 💻🐳

This repository provides a Dockerfile to build a Docker image containing a ready-to-use Axolotl environment within a JupyterLab interface. This setup is designed for seamless deployment on Huggingface Spaces.

## Key Features:

- **Pre-installed Axolotl:** The image includes a working installation of Axolotl, a powerful large language model (LLM) fine-tuning framework.
- **JupyterLab Integration:** Interact with Axolotl directly through a user-friendly JupyterLab interface, enabling interactive development and experimentation.
- **Huggingface Spaces Compatibility:** Effortlessly deploy the Docker container to Huggingface Spaces for easy sharing and collaboration.
- **CUDA Support:** Leverages NVIDIA CUDA for accelerated training and inference on compatible GPUs.

## Getting Started:

1. **Build the Docker Image:**
   ```bash
   docker build -t jupyter-axolotl .
   ```

2. **Run the Docker Container:**
   ```bash
   docker run -it -p 7860:7860 jupyter-axolotl
   ```

3. **Access JupyterLab:**
   Open a web browser and navigate to `http://localhost:7860`. The default token for accessing JupyterLab is `huggingface`.

## Configuration:

The Dockerfile provides several customizable arguments for tailoring the build process:

- `CUDA_VERSION`: Specifies the CUDA version to use (default: 11.8.0).
- `CUDNN_VERSION`: Sets the cuDNN version (default: 8).
- `UBUNTU_VERSION`: Determines the Ubuntu base image version (default: 22.04).
- `AXOLOTL_EXTRAS`: Allows for installing additional Axolotl dependencies (e.g., "deepspeed,flash-attn").
- `PYTHON_VERSION`: Sets the Python version for the environment (default: 3.10).

## Huggingface Spaces Deployment:

To deploy on Huggingface Spaces:

1. Create a new Space and select the "Docker image" SDK.
2. Use the provided Dockerfile and configure any desired arguments.
3. Push the image to your Huggingface registry.
4. Configure the Space settings to use your Docker image.

## Notes:

- The default JupyterLab token is `huggingface`. It's highly recommended to change this token for security purposes, especially in public deployments.
- The `on_startup.sh` script can be used to execute custom commands before JupyterLab starts.
- The `packages.txt` file lists additional Debian packages to install during the build process.
- Refer to the Axolotl documentation for detailed information on using the framework: [https://github.com/OpenAccess-AI-Collective/axolotl](https://github.com/OpenAccess-AI-Collective/axolotl)

This project is a collaborative effort inspired by the work of camenduru, nateraw, osanseviero, and azzr.


Duplicate from SpacesExamples/jupyterlab

Co-authored-by: Nate Raw <nateraw@users.noreply.huggingface.co>
