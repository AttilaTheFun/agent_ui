AgentUI's icon: an Icon Composer document (AgentUI.icon: glass chat bubbles,
the front one typing, on blue). Rendered to .github/icon.png, where Reviews and other tools look for a
repository's icon:

    ictool artwork/repository-icon/AgentUI.icon --export-image --output-file .github/icon.png \
        --platform iOS --rendition Default --width 512 --height 512 --scale 1

(`ictool` is in Xcode's Icon Composer.app, Contents/Executables.)
