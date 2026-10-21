-- Concept textures for Bejeweled Redux: the seven gem colors from the concept art, made with
-- Meshy (image clean-up, then 3D) and rendered as 20-frame spins, plus the concept logo, window
-- border, window icon and stone background. Everything else uses the built-in art.
-- Choose it under Options -> General -> Texture Pack, then /reload.
BejeweledRedux_RegisterTexturePack({
    name = "Concept",
    path = "Interface\\AddOns\\BejeweledRedux_Concept\\images\\",
    extension = ".png",
    textures = {
        gem = true,
        windowBorder = true,
        windowIcon = true,
        windowBackground = true,
        logo = {
            file = "logo.png",
            size = { 1024, 512 },
            regions = { logo = { 0, 0, 1024, 445 } },
            display = { 240, 104 },
        },
    },
})
