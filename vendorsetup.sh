# vendorsetup.sh - Device-specific setup script for OnePlus Avicii

# Color code variables
R="\033[1;31m"
B="\033[1;34m"
G="\033[1;32m"
N="\033[0m" # No Color

# Environment variables
SRC_DIR="${PWD}"
FW_DIR="${SRC_DIR}/vendor/oneplus/firmware"
KERNEL_DIR="${SRC_DIR}/kernel/oneplus/sm7250"
VENDOR_DIR="${SRC_DIR}/vendor/oneplus/avicii"
APPS_DIR="${SRC_DIR}/vendor/oneplus/apps"
KERNELSU_DIR="${KERNEL_DIR}/KernelSU"

# Repo URLs and branches
FW_REPO="https://github.com/XxRagulxX/android_firmware_oneplus_avicii"
KERNEL_REPO="https://github.com/XxRagulxX/android_kernel_oneplus_sm7250"
KERNEL_BRANCH="KernelSU-Next"
VENDOR_REPO="https://github.com/XxRagulxX/android_vendor_oneplus_avicii_ooscam"
APPS_REPO="https://github.com/XxRagulxX/oplus_camera_avicii"

# Dependencies: name, directory, repo variable, (optional) branch variable
declare -a DEPENDENCIES=(
  "FW|${FW_DIR}|FW_REPO"
  "KERNEL|${KERNEL_DIR}|KERNEL_REPO|KERNEL_BRANCH"
  "VENDOR|${VENDOR_DIR}|VENDOR_REPO"
  "APPS|${APPS_DIR}|APPS_REPO"
)

function chk_dependencies() {
  echo -e "${B}Checking Dependencies...${N}"
  for dep in "${DEPENDENCIES[@]}"; do
    IFS='|' read -r NAME DIR REPO_VAR BRANCH_VAR <<< "$dep"
    REPO_URL="${!REPO_VAR}"
    if [[ -d "${DIR}" ]]; then
      echo -e "${G}${NAME} found${N}"
    else
      echo -e "${R}${NAME} not found${N}"
      echo -e "${B}Cloning ${NAME}...${N}"
      if [[ -n "${BRANCH_VAR}" ]]; then
        BRANCH_NAME="${!BRANCH_VAR}"
        git clone --depth=1 -b "${BRANCH_NAME}" "${REPO_URL}" "${DIR}"
      else
        git clone --depth=1 "${REPO_URL}" "${DIR}"
      fi
      echo -e "${G}Successfully cloned ${NAME}${N}"
    fi
    # After kernel is cloned, handle KernelSU-Next
    if [[ "${NAME}" == "KERNEL" ]]; then
      install_kernelsu_next
    fi
  done
}

function install_kernelsu_next() {
  echo -e "${B}Checking for existing KernelSU-Next...${N}"
  if [[ -d "${KERNELSU_DIR}" && -n "$(ls -A "${KERNELSU_DIR}")" ]]; then
    echo -e "${G}KernelSU-Next already present. Skipping download.${N}"
    manage_kernelsu_symlink
    return 0
  fi

  echo -e "${B}Downloading latest KernelSU-Next release...${N}"
  # Get latest release zip URL from GitHub API
  LATEST_URL=$(curl -s https://api.github.com/repos/KernelSU-Next/KernelSU-Next/releases/latest | \
    grep 'browser_download_url' | grep '.zip' | head -n 1 | cut -d '"' -f 4)
  if [[ -z "${LATEST_URL}" ]]; then
    echo -e "${R}Failed to fetch KernelSU-Next release URL.${N}"
    return 1
  fi
  mkdir -p "${KERNELSU_DIR}"
  TMP_ZIP="${KERNELSU_DIR}/kernelsu-next.zip"
  curl -L "${LATEST_URL}" -o "${TMP_ZIP}"
  unzip -oq "${TMP_ZIP}" -d "${KERNELSU_DIR}"
  rm -f "${TMP_ZIP}"
  echo -e "${G}KernelSU-Next extracted to ${KERNELSU_DIR}${N}"
  manage_kernelsu_symlink
}

function manage_kernelsu_symlink() {
  echo -e "${B}Checking KernelSU symlink in drivers...${N}"
  DRIVERS_DIR="${KERNEL_DIR}/drivers"
  LINK_NAME="kernelsu"
  TARGET="../KernelSU/kernel"

  (
    cd "${DRIVERS_DIR}" || { echo -e "${R}Failed to enter ${DRIVERS_DIR}${N}"; return 1; }
    # Remove if not a symlink or incorrect
    if [[ -L "${LINK_NAME}" ]]; then
      CURRENT_TARGET=$(readlink "${LINK_NAME}")
      if [[ "${CURRENT_TARGET}" == "${TARGET}" ]]; then
        echo -e "${G}KernelSU symlink is correct.${N}"
        return
      else
        echo -e "${R}KernelSU symlink incorrect. Fixing...${N}"
        rm -f "${LINK_NAME}"
      fi
    elif [[ -e "${LINK_NAME}" ]]; then
      echo -e "${R}KernelSU path exists but is not a symlink. Removing...${N}"
      rm -rf "${LINK_NAME}"
    fi
    ln -sf "${TARGET}" "${LINK_NAME}"
    echo -e "${G}KernelSU symlink created: ${DRIVERS_DIR}/${LINK_NAME} -> ${TARGET}${N}"
  )
}