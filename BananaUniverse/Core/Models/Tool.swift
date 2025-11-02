//
//  Tool.swift
//  noname_banana
//
//  Created by AI Assistant on 16.10.2025.
//  Tool Data Model
//

import Foundation
import SwiftUI

// MARK: - Tool Data Model
struct Tool: Identifiable {
    let id: String
    let title: LocalizedStringKey
    let imageURL: URL?
    let category: String
    let requiresPro: Bool
    let modelName: String
    let placeholderIcon: String // For MVP, use SF Symbol
    let prompt: String // Associated prompt for the tool
}

// MARK: - Static Tool Data
extension Tool {
    static let mainTools: [Tool] = [
        Tool(id: "remove_object", title: "Remove Object from Image", imageURL: nil as URL?, category: "main_tools", requiresPro: false, modelName: "lama-cleaner", placeholderIcon: "eraser.fill", prompt: "Remove the selected object naturally, keeping the background seamless and realistic"),
        Tool(id: "remove_background", title: "Remove Background", imageURL: nil as URL?, category: "main_tools", requiresPro: false, modelName: "rembg", placeholderIcon: "scissors", prompt: "Remove the background cleanly, keeping edges sharp and lighting natural"),
        Tool(id: "put_items_on_models", title: "Put Items on Models", imageURL: nil as URL?, category: "main_tools", requiresPro: false, modelName: "virtual-try-on", placeholderIcon: "person.crop.rectangle", prompt: "Place the selected item naturally on the person, matching lighting, angle, and scale"),
        Tool(id: "add_objects", title: "Add Objects to Images", imageURL: nil as URL?, category: "main_tools", requiresPro: false, modelName: "stable-diffusion-inpainting", placeholderIcon: "plus.square.fill", prompt: "Add the object realistically into the scene, blending light, shadow, and texture perfectly"),
        Tool(id: "change_perspective", title: "Change Image Perspectives", imageURL: nil as URL?, category: "main_tools", requiresPro: false, modelName: "perspective-transform", placeholderIcon: "rotate.3d", prompt: "Adjust the image perspective realistically, keeping proportions and depth accurate"),
        Tool(id: "generate_series", title: "Generate Image Series", imageURL: nil as URL?, category: "main_tools", requiresPro: false, modelName: "stable-diffusion", placeholderIcon: "square.grid.3x3.fill", prompt: "Create a realistic variation of this image, keeping the subject consistent"),
        Tool(id: "style_transfer", title: "Style Transfers on Images", imageURL: nil as URL?, category: "main_tools", requiresPro: false, modelName: "neural-style", placeholderIcon: "paintbrush.fill", prompt: "Apply the selected artistic style to this image while preserving key details and structure")
    ]
    
    static let proLooksTools: [Tool] = [
        Tool(id: "linkedin_headshot", title: "LinkedIn Headshot", imageURL: nil as URL?, category: "pro_looks", requiresPro: false, modelName: "professional-headshot", placeholderIcon: "person.crop.square", prompt: "Transform this photo into a professional LinkedIn headshot with clean light and natural tone"),
        Tool(id: "passport_photo", title: "Passport Photo", imageURL: nil as URL?, category: "pro_looks", requiresPro: false, modelName: "passport-photo-generator", placeholderIcon: "doc.text.image", prompt: "Generate a passport-style photo with plain background and balanced facial lighting"),
        Tool(id: "twitter_avatar", title: "Twitter/X Avatar", imageURL: nil as URL?, category: "pro_looks", requiresPro: false, modelName: "social-media-avatar", placeholderIcon: "at", prompt: "Create a clear, vibrant avatar optimized for small-size visibility and natural color tone"),
        Tool(id: "gradient_headshot", title: "Gradient Headshot", imageURL: nil as URL?, category: "pro_looks", requiresPro: false, modelName: "gradient-background-portrait", placeholderIcon: "square.split.diagonal.2x2", prompt: "Generate a professional headshot with a soft gradient background and balanced tone"),
        Tool(id: "resume_photo", title: "Resume Photo", imageURL: nil as URL?, category: "pro_looks", requiresPro: false, modelName: "professional-resume-photo", placeholderIcon: "doc.plaintext", prompt: "Create a professional resume photo with neutral lighting and confident expression"),
        Tool(id: "slide_background", title: "Slide Background Maker", imageURL: nil as URL?, category: "pro_looks", requiresPro: false, modelName: "presentation-background-generator", placeholderIcon: "rectangle.on.rectangle", prompt: "Design a clean, balanced slide background with good text readability and visual harmony"),
        Tool(id: "thumbnail_generator", title: "Thumbnail Generator", imageURL: nil as URL?, category: "pro_looks", requiresPro: false, modelName: "youtube-thumbnail-generator", placeholderIcon: "play.rectangle.fill", prompt: "Generate an engaging thumbnail with strong focus, clear subject, and bold visual contrast"),
        Tool(id: "cv_portrait", title: "CV/Portfolio Portrait", imageURL: nil as URL?, category: "pro_looks", requiresPro: false, modelName: "portfolio-portrait", placeholderIcon: "person.text.rectangle", prompt: "Create a modern portfolio portrait with professional lighting and authentic expression"),
        Tool(id: "profile_banner", title: "Profile Banner Generator", imageURL: nil as URL?, category: "pro_looks", requiresPro: false, modelName: "banner-generator", placeholderIcon: "rectangle.fill", prompt: "Generate a stylish banner image with balanced composition and soft background focus"),
        Tool(id: "designer_id_photo", title: "Designer-Style ID Photo", imageURL: nil as URL?, category: "pro_looks", requiresPro: false, modelName: "designer-id-photo", placeholderIcon: "person.crop.circle.badge.checkmark", prompt: "Create a contemporary ID photo with clean lighting and designer aesthetic")
    ]
    
    static let restorationTools: [Tool] = [
        Tool(id: "image_upscaler", title: "Image Upscaler (2x-4x)", imageURL: nil as URL?, category: "restoration", requiresPro: false, modelName: "upscale", placeholderIcon: "arrow.up.backward.and.arrow.down.forward", prompt: "Enhance and upscale this image sharply, keeping all details and textures intact"),
        Tool(id: "historical_photo_restore", title: "Historical Photo Restore", imageURL: nil as URL?, category: "restoration", requiresPro: false, modelName: "codeformer", placeholderIcon: "clock.arrow.circlepath", prompt: "Restore this old photo faithfully, preserving its original look and emotional tone")
    ]
    
    static let seasonalTools: [Tool] = [
        // Thanksgiving Tools
        Tool(id: "thanksgiving_magic", title: "Thanksgiving Magic Edit", imageURL: nil as URL?, category: "seasonal", requiresPro: false, modelName: "nano-banana/edit", placeholderIcon: "leaf.fill", prompt: "Transform this image with warm thanksgiving atmosphere, adding autumn colors, cozy lighting, and festive thanksgiving elements while maintaining natural realism"),
        Tool(id: "thanksgiving_portrait", title: "Thanksgiving Family Portrait", imageURL: nil as URL?, category: "seasonal", requiresPro: false, modelName: "nano-banana/edit", placeholderIcon: "person.3.fill", prompt: "Create a warm family portrait with thanksgiving setting, soft autumn lighting, and cozy family gathering atmosphere"),
        Tool(id: "autumn_colors", title: "Autumn Color Enhancer", imageURL: nil as URL?, category: "seasonal", requiresPro: false, modelName: "nano-banana/edit", placeholderIcon: "paintpalette.fill", prompt: "Enhance this image with beautiful autumn colors, warm golden tones, and seasonal foliage effects"),
        
        // Christmas Tools  
        Tool(id: "christmas_magic", title: "Christmas Magic Edit", imageURL: nil as URL?, category: "seasonal", requiresPro: false, modelName: "nano-banana/edit", placeholderIcon: "gift.fill", prompt: "Add magical christmas elements to this image - snow, warm lights, festive decorations, and holiday magic while keeping it natural and realistic"),
        Tool(id: "holiday_portrait", title: "Holiday Portrait", imageURL: nil as URL?, category: "seasonal", requiresPro: false, modelName: "nano-banana/edit", placeholderIcon: "star.fill", prompt: "Transform into a beautiful holiday portrait with festive lighting, warm winter atmosphere, and elegant holiday styling"),
        Tool(id: "winter_wonderland", title: "Winter Wonderland", imageURL: nil as URL?, category: "seasonal", requiresPro: false, modelName: "nano-banana/edit", placeholderIcon: "snowflake", prompt: "Create a magical winter wonderland scene with realistic snow, winter lighting, and enchanting seasonal atmosphere"),
        Tool(id: "santa_hat_overlay", title: "Santa Hat Overlay", imageURL: nil as URL?, category: "seasonal", requiresPro: false, modelName: "nano-banana/edit", placeholderIcon: "person.crop.circle.badge.plus", prompt: "Add a festive Santa hat naturally to the person in this image, matching lighting and perspective perfectly"),
        
        // New Year Tools
        Tool(id: "new_year_glamour", title: "New Year Glamour", imageURL: nil as URL?, category: "seasonal", requiresPro: false, modelName: "nano-banana/edit", placeholderIcon: "sparkles", prompt: "Create a glamorous new year portrait with celebration lighting, elegant styling, and festive party atmosphere"),
        Tool(id: "confetti_celebration", title: "Confetti Celebration", imageURL: nil as URL?, category: "seasonal", requiresPro: false, modelName: "nano-banana/edit", placeholderIcon: "party.popper.fill", prompt: "Add festive confetti and celebration elements to this image with realistic lighting and natural integration")
    ]
}

