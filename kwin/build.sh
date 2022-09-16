#!/bin/bash

# -------------------------------------------------------------------------------------- #
#           )                                                   (                        #
#        ( /(   (  (               )    (       (  (  (         )\ )    (  (             #
#        )\()) ))\ )(   (         (     )\ )    )\))( )\  (    (()/( (  )\))(  (         #
#       ((_)\ /((_|()\  )\ )      )\  '(()/(   ((_)()((_) )\ )  ((_)))\((_)()\ )\        #
#       | |(_|_))( ((_)_(_/(    _((_))  )(_))  _(()((_|_)_(_/(  _| |((_)(()((_|(_)       #
#       | '_ \ || | '_| ' \))  | '  \()| || |  \ V  V / | ' \)) _` / _ \ V  V (_-<       #
#       |_.__/\_,_|_| |_||_|   |_|_|_|  \_, |   \_/\_/|_|_||_|\__,_\___/\_/\_//__/       #
#                                  |__/                                                  #
# -------------------------------------------------------------------------------------- #

# SPDX-FileCopyrightText: Simon Schneegans <code@simonschneegans.de>
# SPDX-License-Identifier: MIT

# This scripts takes the shaders of Burn-My-Windows as well as some other input files from
# the directories next to this script and creates effect for KDE's Kwin.

# Exit the script when one command fails.
set -e

# Go to the script's directory.
cd "$( cd "$( dirname "$0" )" && pwd )" || \
  { echo "ERROR: Could not find kwin directory."; exit 1; }

# We will store the effect directories in this directory.
BUILD_DIR="_build"

# Create it if it's not there yet.
mkdir -p "$BUILD_DIR"

# This method is called one for each effect. The parameters are as follows:
# $1: The nick of the effect (e.g. "energize-a")
# $2: The name of the effect (e.g. "Energize A")
# $3: A short description of the effect (e.g. "Beam your windows away")
generate() {

  # We use the nick for the effect's directory name by replacing dashes with underscoares.
  DIR_NAME="kwin4_effect_$(echo "$1" | tr '-' '_')"

  # We transform the nick to CamelCase for the JavaScript class name.
  EFFECT_CLASS="BurnMyWindows$(sed -r 's/(^|-)(\w)/\U\2/g' <<<"$1")Effect"

  # Now create all required resource directories.
  mkdir -p "$BUILD_DIR/$DIR_NAME/contents/shaders"
  mkdir -p "$BUILD_DIR/$DIR_NAME/contents/code"
  mkdir -p "$BUILD_DIR/$DIR_NAME/contents/config"
  mkdir -p "$BUILD_DIR/$DIR_NAME/contents/ui"

  # Copy the config file if it exists.
  if [ -f "$1/main.xml" ]; then
    cp "$1/main.xml" "$BUILD_DIR/$DIR_NAME/contents/config"
  fi

  # Copy the ui file if it exists.
  if [ -f "$1/config.ui" ]; then
    cp "$1/config.ui" "$BUILD_DIR/$DIR_NAME/contents/ui"
  fi

  # Now we create the effect's JavaScript source file. This is done by taking main.js.in
  # and replacing some placeholders with effect-specific files and values. 
  ON_SETTINGS_CHANGE=""
  ON_ANIMATION_BEGIN=""

  # If the effect's directory contains a onSettingsChanged.js, we replace the
  # corresponding placeholder with it's content. We replace all occurences of / temporily
  # so that the REGEX works.
  if [ -f "$1/onSettingsChanged.js" ]; then
    ON_SETTINGS_CHANGE=$(tr '/' '\f' < "$1/onSettingsChanged.js")
  fi

  # Similarily, we will inject the contents of onAnimationBegin.js.
  if [ -f "$1/onAnimationBegin.js" ]; then
    ON_ANIMATION_BEGIN=$(tr '/' '\f' < "$1/onAnimationBegin.js")
  fi

  cp main.js.in "$BUILD_DIR/$DIR_NAME/contents/code/main.js"
  perl -pi -e "s/%ON_SETTINGS_CHANGE%/$ON_SETTINGS_CHANGE/g;" "$BUILD_DIR/$DIR_NAME/contents/code/main.js"
  perl -pi -e "s/%ON_ANIMATION_BEGIN%/$ON_ANIMATION_BEGIN/g;" "$BUILD_DIR/$DIR_NAME/contents/code/main.js"
  perl -pi -e "s/%EFFECT_CLASS%/$EFFECT_CLASS/g;"             "$BUILD_DIR/$DIR_NAME/contents/code/main.js"
  perl -pi -e "s/%SHADER_NAME%/$1/g;"                         "$BUILD_DIR/$DIR_NAME/contents/code/main.js"
  perl -pi -e "s/\f/\//g;"                                    "$BUILD_DIR/$DIR_NAME/contents/code/main.js"

  # Now create the metadata.desktop file. Again, we replace some placeholders.
  cp metadata.desktop.in "$BUILD_DIR/$DIR_NAME/metadata.desktop"
  perl -pi -e "s/%ICON%/$1/g;"            "$BUILD_DIR/$DIR_NAME/metadata.desktop"
  perl -pi -e "s/%NAME%/$2/g;"            "$BUILD_DIR/$DIR_NAME/metadata.desktop"
  perl -pi -e "s/%DESCRIPTION%/$3/g;"     "$BUILD_DIR/$DIR_NAME/metadata.desktop"
  perl -pi -e "s/%DIR_NAME%/$DIR_NAME/g;" "$BUILD_DIR/$DIR_NAME/metadata.desktop"

  # Now create the two required shader files. We prepend the common.glsl to each shader.
  # We also define KWIN and KWIN_LEGACY. The code in common.glsl takes some different
  # paths based on these defines.
  {
    echo "#version 140"
    echo "#define KWIN"
    echo ""
    echo "// This file is automatically generated during the build process."
    echo ""
    cat "../resources/shaders/common.glsl"
    cat "../resources/shaders/$1.frag"
  } > "$BUILD_DIR/$DIR_NAME/contents/shaders/$1_core.frag"

  {
    echo "#define KWIN_LEGACY"
    echo ""
    echo "// This file is automatically generated during the build process."
    echo ""
    cat "../resources/shaders/common.glsl"
    cat "../resources/shaders/$1.frag"
  } > "$BUILD_DIR/$DIR_NAME/contents/shaders/$1.frag"

  # If clang-format is installed, try to beautify the code a bit.
  if command -v clang-format &> /dev/null
  then
      clang-format -i "$BUILD_DIR/$DIR_NAME/contents/code/main.js"
  fi

  # Create an archive which can be uploaded to https://store.kde.org.
  # shellcheck disable=SC2046
  tar -cjf "$DIR_NAME.tar.gz" -C "$BUILD_DIR/$DIR_NAME" $(ls "$BUILD_DIR/$DIR_NAME")
}

# Now run the above method for all supported effects.

# The apparition effect is disabled for now. I have not yet found a way to upscale the
# window canvas during the animation.
#generate "apparition" "[BMW] Apparition" "This effect hides your windows by violently sucking them into the void of magic"

generate "energize-a"  "Energize A [Burn-My-Windows]"  "Beam your windows away"
generate "energize-b"  "Energize B [Burn-My-Windows]"  "Using different transporter technology results in an alternative visual effect"
generate "doom"        "Doom [Burn-My-Windows]"        "Melt your windows"
generate "fire"        "Fire [Burn-My-Windows]"        "The classic effect inspired by Compiz"
generate "hexagon"     "Hexagon [Burn-My-Windows]"     "With glowing lines and hexagon-shaped tiles, this effect looks very sci-fi"
generate "incinerate"  "Incinerate [Burn-My-Windows]"  "A less snappy but definitely more fancy take on the fire effect"
generate "pixelate"    "Pixelate [Burn-My-Windows]"    "Pixelate the window and randomly hide the pixels"
generate "pixel-wheel" "Pixel Wheel [Burn-My-Windows]" "Pixelate the window and hide the pixels in a wheel-like fashion"
generate "pixel-wipe"  "Pixel Wipe [Burn-My-Windows]"  "Pixelate the window and hide the pixels radially, starting from the pointer position"
generate "tv"          "TV Effect [Burn-My-Windows]"   "Make windows close like turning off a TV"
generate "wisps"       "Wisps [Burn-My-Windows]"       "Let your windows be carried away to the realm of dreams by these little fairies"

# Finally, create an archive for the effects.
# shellcheck disable=SC2046
tar -cjf "burn_my_windows_kwin4.tar.gz" -C "$BUILD_DIR" $(ls "$BUILD_DIR")