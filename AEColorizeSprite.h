#import "CCSprite.h"

@interface AEColorizeSprite : CCSprite {
	BOOL		_tintingEnabled;

	GLfloat		_tintHue;
	GLfloat		_tintSat;
	GLfloat		_tintBrt;
	BOOL		_usePerceptualDesaturation;
	
	GLfloat		_opacityLoc;
	GLuint		_tintHueLoc;
	GLuint		_tintSatLoc;
	GLuint		_tintBrtLoc;
	GLuint		_usePerceptualDesaturationLoc;
}

@property BOOL tintingEnabled;
@property GLfloat tintHue;
@property GLfloat tintSat;
@property GLfloat tintBrt;
@property BOOL usePerceptualDesaturation;

- (id)initWithSpriteFrameName:(NSString*)aName tintHue:(float)hue tintSat:(float)sat tintBrt:(float)brt;
- (id)initWithFile:(NSString*)filename tintHue:(float)hue tintSat:(float)sat tintBrt:(float)brt;

@end
