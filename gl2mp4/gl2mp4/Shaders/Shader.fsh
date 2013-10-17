//
//  Shader.fsh
//  gl2mp4
//
//  Created by harriscao on 13-10-17.
//  Copyright (c) 2013年 harriscao. All rights reserved.
//

varying lowp vec4 colorVarying;

void main()
{
    gl_FragColor = colorVarying;
}
