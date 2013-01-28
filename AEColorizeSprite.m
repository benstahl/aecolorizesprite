#import "AEColorizeSprite.h"
#import "CCShaderCache.h"
#import "ccGLStateCache.h"
#import "CCGLProgram.h"

#define kQuadSize sizeof(quad_.bl)

#pragma mark - AEColorizeSprite

@implementation AEColorizeSprite

/* =============================================================================
 Designated initializer.
 ============================================================================ */
- (id)initWithSpriteFrameName:(NSString*)aName tintHue:(float)hue tintSat:(float)sat tintBrt:(float)brt {
	if (self = [super initWithSpriteFrameName:aName]) {
		self.blendFunc = (ccBlendFunc) { GL_SRC_ALPHA, GL_ONE }; // Additive function
		self.tintHue = hue;
		self.tintSat = sat;
		self.tintBrt = brt;
		self.usePerceptualDesaturation = YES;
		
		/* --- Cache default shader so tinting shader can be disabled later. --- */
		if (shaderProgram_) {
			[sShaderCache addProgram:shaderProgram_ forKey:kDefaultShaderProgramKey];
		}

		self.tintingEnabled = YES;
	}
	
	return self;
}

/* ========================================================================== */
- (id)initWithFile:(NSString*)filename tintHue:(float)hue tintSat:(float)sat tintBrt:(float)brt {
	// Create the sprite, it will be added to the sprite frame cache.
	CCSprite *sprite = [[CCSprite alloc] initWithFile:filename];
	CCSpriteFrame *spriteFrame = [[CCSpriteFrame alloc] initWithTextureFilename:filename rect:sprite.textureRect];
	[sFrameCache addSpriteFrame:spriteFrame name:filename];
	NSAssert2(sprite, @"AEColorizeSprite: Failed to create sprite from file '%@'.", NSStringFromSelector(_cmd), filename);
	return [self initWithSpriteFrameName:filename tintHue:hue tintSat:sat tintBrt:brt];
}

/* ========================================================================== */
- (void)enableTintingShader {
	shaderProgram_ = [sShaderCache programForKey:kColorizeSpriteShaderProgramKey];
	/* --- Check to see if the program is already in the cache, where it can be re-used instead of re-creating it each time. --- */
	if (!shaderProgram_) {
		// Tell Cocos2D to use our custom fragment shader, and the default textured vertex shader.
		const GLchar * fragmentSource = (GLchar*) [[NSString stringWithContentsOfFile:[[CCFileUtils sharedFileUtils] fullPathFromRelativePath:@"AEColorize.fsh"] encoding:NSUTF8StringEncoding error:nil] UTF8String];
		NSAssert(fragmentSource != nil, @"AEColorizeSprite: Fragment shader source invalid or could not be loaded.");

		shaderProgram_ = [[CCGLProgram alloc] initWithVertexShaderByteArray:ccPositionTextureA8Color_vert
													fragmentShaderByteArray:fragmentSource];
		CHECK_GL_ERROR_DEBUG();
		NSAssert(shaderProgram_ != nil, @"AEColorizeSprite: Custom shader program is invalid or could not be loaded.");

		/* --- Set attributes. --- */
		[shaderProgram_ addAttribute:kCCAttributeNamePosition index:kCCVertexAttrib_Position];
		[shaderProgram_ addAttribute:kCCAttributeNameColor index:kCCVertexAttrib_Color];
		[shaderProgram_ addAttribute:kCCAttributeNameTexCoord index:kCCVertexAttrib_TexCoords];
		CHECK_GL_ERROR_DEBUG();

		[shaderProgram_ link];
		CHECK_GL_ERROR_DEBUG();

		[shaderProgram_ updateUniforms];
		CHECK_GL_ERROR_DEBUG();

		// Add the program to the cache so other sprites don't have to re-create it.
		if (shaderProgram_) {
			[sShaderCache addProgram:shaderProgram_ forKey:kColorizeSpriteShaderProgramKey];
		}
	}

	/*--- Set uniform locations. --- */
	_opacityLoc = glGetUniformLocation(shaderProgram_->program_, "u_opacity");
	_tintHueLoc = glGetUniformLocation(shaderProgram_->program_, "u_tintHue");
	_tintSatLoc = glGetUniformLocation(shaderProgram_->program_, "u_tintSat");
	_tintBrtLoc = glGetUniformLocation(shaderProgram_->program_, "u_tintBrt");
	_usePerceptualDesaturationLoc = glGetUniformLocation(shaderProgram_->program_, "u_usePerceptualDesaturation");
}

/* ========================================================================== */
- (void)enableDefaultShader {
	shaderProgram_ = [sShaderCache programForKey:kDefaultShaderProgramKey];
}

#pragma mark - accessors

/* ========================================================================== */
- (float)tintHue {
	return _tintHue;
}

/* =============================================================================
 Input: 0.0 to 360.0
 Output: 0.0 to 1.0
 ============================================================================ */
- (void)setTintHue:(GLfloat)newHue {
	if (newHue < 0.0) {
		newHue = -remainderf(newHue, 360.0);
	}

	if (newHue >= 360.0) {
		newHue = remainderf(newHue, 360.0);
	}

	_tintHue = newHue / 360.0; // 0.0 <---> +1.0
}

/* ========================================================================== */
- (float)tintSat {
	return _tintSat;
}

/* =============================================================================
 Input: 0.0 to 100.0
 Output: 0.0 to 1.0
 ============================================================================ */
- (void)setTintSat:(GLfloat)newSat {
	_tintSat = clampf(newSat, 0.0, 100.0) / 100.0; // 0.0 <---> +1.0
}

/* ========================================================================== */
- (float)tintBrt {
	return _tintBrt;
}

/* =============================================================================
 Input: -100.0 to 100.0
 Output: -1.0 to 1.0
 ============================================================================ */
- (void)setTintBrt:(GLfloat)newBrt {
	_tintBrt = clampf(newBrt, -100.0, 100.0) / 100.0; // -1.0 <---> +1.0
}

/* ========================================================================== */
- (BOOL)tintingEnabled {
	return _tintingEnabled;
}

/* ========================================================================== */
- (void)setTintingEnabled:(BOOL)tintingEnabled {
	_tintingEnabled = tintingEnabled;
	if (_tintingEnabled) {
		[self enableTintingShader];
	} else {
		[self enableDefaultShader];
	}
}

#pragma mark - superclass overrides

/* ========================================================================== */
- (void)draw {
	if (_tintingEnabled) {
		/* --- Basic OpenGL drawing setup. --- */
		ccGLEnableVertexAttribs(kCCVertexAttribFlag_PosColorTex);
		ccGLBlendFunc(blendFunc_.src, blendFunc_.dst);
		[shaderProgram_ use];
		[shaderProgram_ setUniformForModelViewProjectionMatrix];

		/* --- Bind textures. --- */
		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, [texture_ name]);

		/* --- Pass in uniforms. --- */
		glUniform1f(_tintHueLoc, _tintHue);
		glUniform1f(_tintSatLoc, _tintSat);
		glUniform1f(_tintBrtLoc, _tintBrt);
		glUniform1f(_opacityLoc, opacity_ / 255.0);
		glUniform1i(_usePerceptualDesaturationLoc, _usePerceptualDesaturation);

		/* --- Manual setup for OpenGL drawing. We have to do this because we're not calling [super draw]. --- */
		long offset = (long)&quad_;

		/* --- vertex --- */
		NSInteger diff = offsetof(ccV3F_C4B_T2F, vertices);
		glVertexAttribPointer(kCCVertexAttrib_Position, 3, GL_FLOAT, GL_FALSE, kQuadSize, (void*)(offset + diff));

		/* --- texCoords --- */
		diff = offsetof(ccV3F_C4B_T2F, texCoords);
		glVertexAttribPointer(kCCVertexAttrib_TexCoords, 2, GL_FLOAT, GL_FALSE, kQuadSize, (void*)(offset + diff));

		/* --- color --- */
		diff = offsetof(ccV3F_C4B_T2F, colors);
		glVertexAttribPointer(kCCVertexAttrib_Color, 4, GL_UNSIGNED_BYTE, GL_TRUE, kQuadSize, (void*)(offset + diff));

		/* --- Draw it. --- */
		glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

		/* --- Reset active texture. --- */
		glActiveTexture(GL_TEXTURE0);
	} else {
		[super draw];
	}
}

@end
