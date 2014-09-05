fragShaderSource = "
  precision highp float;
  uniform vec4 u_color;
  void main(void) {
    gl_FragColor = u_color;
  }
"

vtxShaderSource = "
  attribute vec3 a_position;
  uniform vec4 u_color;
  uniform mat4 u_mvMatrix;
  uniform mat4 u_pMatrix;
  void main(void) {
    gl_Position = u_pMatrix * u_mvMatrix * vec4(a_position, 1.0);
  }
"

gl = null;
shaderProgram = null;

get_shader = (type, source) ->
  shader = gl.createShader(type)
  gl.shaderSource(shader, source)
  gl.compileShader(shader)
  shader

initGL = ->
  canvas = $('canvas')[0]
  gl = canvas.getContext("experimental-webgl", {antialias: false})
  gl.viewport(0, 0, canvas.width, canvas.height)

initShaders = ->
  vertexShader = get_shader(gl.VERTEX_SHADER, vtxShaderSource)
  fragmentShader = get_shader(gl.FRAGMENT_SHADER, fragShaderSource)
  shaderProgram = gl.createProgram()
  gl.attachShader(shaderProgram, vertexShader)
  gl.attachShader(shaderProgram, fragmentShader)
  gl.linkProgram(shaderProgram)
  gl.useProgram(shaderProgram)
  shaderProgram.aposAttrib = gl.getAttribLocation(shaderProgram, "a_position")
  gl.enableVertexAttribArray(shaderProgram.aposAttrib)
  shaderProgram.colorUniform = gl.getUniformLocation(shaderProgram, "u_color")
  shaderProgram.pMUniform = gl.getUniformLocation(shaderProgram, "u_pMatrix")
  shaderProgram.mvMUniform = gl.getUniformLocation(shaderProgram, "u_mvMatrix")


initScene = ->
  gl.clearColor(0.0, 0.0, 0.0, 1.0)
  mvMatrix =
    [1, 0, 0, 0,
    0, 1, 0.00009999999747378752, 0,
    0, -0.00009999999747378752, 1, 0,
    0, 1.3552527156068805e-20, -8, 1]
  pMatrix =
    [2.4142136573791504, 0, 0, 0,
    0, 2.4142136573791504, 0, 0,
    0, 0, -1.0020020008087158, -1,
    0, 0, -0.20020020008087158, 0]
  gl.enable(gl.DEPTH_TEST)
  gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
  gl.uniformMatrix4fv(shaderProgram.pMUniform, false, new Float32Array(pMatrix))
  gl.uniformMatrix4fv(shaderProgram.mvMUniform, false, new Float32Array(mvMatrix))

initBuffer = (glELEMENT_ARRAY_BUFFER, data) ->
  buf = gl.createBuffer()
  gl.bindBuffer(glELEMENT_ARRAY_BUFFER, buf)
  gl.bufferData(glELEMENT_ARRAY_BUFFER, data, gl.STATIC_DRAW)
  buf

initBuffers = (vtx, idx) ->
  vbuf = initBuffer(gl.ARRAY_BUFFER, vtx)
  ibuf = initBuffer(gl.ELEMENT_ARRAY_BUFFER, idx)
  gl.vertexAttribPointer(shaderProgram.aposAttrib, 3, gl.FLOAT, false, 0, 0)

unbindBuffers = ->
  gl.bindBuffer(gl.ARRAY_BUFFER, null)
  gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, null)


drawLine = (vec1, vec2) ->
  vtx = new Float32Array([vec1.x, vec1.y, 0.0, vec2.x, vec2.y, 0.0])
  idx = new Uint16Array([0, 1])
  initBuffers(vtx, idx)
  gl.lineWidth(0.1)
  gl.uniform4f(shaderProgram.colorUniform, 1, 1, 1, 1)
  gl.drawElements(gl.LINES, 2, gl.UNSIGNED_SHORT, 0)
  gl.flush()
  unbindBuffers()

class Vector
  @add: (vec1, vec2) ->
    new Vector(vec1.x + vec2.x, vec1.y + vec2.y)

  @origin: new Vector(0.0, 0.0)

  constructor: (@x, @y) ->

  scale: (scalar) ->
    new Vector(@x * scalar, @y * scalar)

  length: ->
    Math.sqrt(@x * @x + @y * @y)

  unit: ->
    new Vector(@x / @length(), @y / @length())

  setLength: (length) ->
    @unit().scale(length)

class StateManager
  constructor: ->
    @reset()

  particleSpeed: null

  reset: ->
    @position = Vector.origin
    @particleSpeed = 0.5

stateManager = new StateManager()

class Token
  do: -> console.log("Unimplemented do!")

  applyArgs: (args) ->
    @args = args

  applyBinding: (bindingName, val) ->
    @args = _.map(@args, (x) -> if x is bindingName then val else x) if @args

  @get: (str, args) ->
    _.tap(@tokenMap[str], (token) -> token.applyArgs(args))

class LoopToken
  constructor: (@val, @binding, @childToken) ->

  # TODO(chris): inherited bindings

  do: ->
    for index in [1..@val]
      @childToken.applyBinding(@binding, index) if @binding
      @childToken.do()

class CompositeToken
  constructor: (@childTokens) ->

  # TODO(chris): inherited bindings

  do: ->
    _.forEach @childTokens, (childToken) ->
      childToken.do()

class MoveToken extends Token
  constructor: (x, y) ->
    @vector = new Vector(x, y)

  do: ->
    oldPosition = stateManager.position
    newPosition = Vector.add(oldPosition, @vector.setLength(stateManager.particleSpeed))
    drawLine(oldPosition, newPosition)
    stateManager.position = newPosition

class RandomMoveToken extends MoveToken
  constructor: ->

  do: ->
    @vector = new Vector(Math.random() - 0.5, Math.random() - 0.5)
    super

class SetLengthToken extends Token
  constructor: ->
    @length = 0.5

  do: ->
    stateManager.particleSpeed = @args[0]

class ResetToken extends Token
  do: ->
    stateManager.reset()

Token.tokenMap =
  n: new MoveToken(0.0, 1.0)
  e: new MoveToken(1.0, 0.0)
  s: new MoveToken(0.0, -1.0)
  w: new MoveToken(-1.0, 0.0)
  rand: new RandomMoveToken()
  len: new SetLengthToken()
  reset: new ResetToken()

class Segment
  constructor: (segmentString) ->
    @segmentString = segmentString.trim()

  loop: ->

  tokenString: ->
    @segmentString.split("(")[0]

  args: ->
    # assuming no trailing spaces
    argString = @segmentString.split("(")[1]
    _.initial(argString).join('').split(',').map((x) -> Number(x.trim())) if argString

getSegments = (codeString) ->
  numParens = 0
  currentSegment = ""
  segments = []

  _.forEach codeString, (character) ->
    if character is ";" and numParens is 0
      segments.push(currentSegment)
      currentSegment = ""
    else
      if character is "("
        numParens += 1
      else if character is ")"
        numParens -= 1
        # TODO - throw error if numParens < 0

      currentSegment += character

  if currentSegment.length > 0
    segments.push(currentSegment)

  segments

peelable = (codeString) ->
  codeString = codeString.trim()
  indexOfFirstParen = _.indexOf(codeString, "(")
  indexOfLastParen = _.lastIndexOf(codeString, ")")
  indexOfFirstParen is 0 and indexOfLastParen is codeString.length - 1

peel = (codeString) ->
  codeString.slice(0, codeString.length)

getInnerSegments = (codeString) ->
  # getSegments(codeString) should have length 1
  
  # first, remove outer parens
  codeString = codeString.trim()

  innerCodeString = codeString.slice(indexOfFirstParen + 1, indexOfLastParen)

"(a)"
"(a;5:(c;d))"

getToken = (segmentString) ->
  # first we check if it has subsegments - if it does then we form a
  # composite by recursively mapping getToken over those segments
  

  # if it doesn't have subsegments then we see if it's a loop, etc.
  segmentParts = segmentString.split(":")
  if segmentParts[1]?
    # we have a loop!
    loopVal = segmentParts[0].trim()
    rest = segmentParts[1..].join('')
    val = parseInt(loopVal.split("$")[0])
    binding = loopVal.split("$")[1]
    new LoopToken(val, binding, getToken(rest))
  else
    # no loop :(
    segment = new Segment(segmentString)
    Token.get(segment.tokenString(), segment.args())

$(document).ready ->
  initGL()
  initShaders()
  initScene()

  $('#prompt').keypress (event) ->
    if event.keyCode is 13
      promptText = $('#prompt').val()
      segmentStrings = _.map getSegments(promptText), (x) -> x.trim()
      initScene()
      stateManager.reset()
      _.forEach segmentStrings, (segmentString) ->
        getToken(segmentString).do()

# Segment test
# s = new Segment("  yo(  1,2 ,3 ) ")
# console.log(s.tokenString())
# console.log(s.args())
#
# s = new Segment(" yo    ")
# console.log(s.tokenString())
# console.log(s.args())
#
#

# Get Segments Test
#
#
# simpleString = "simple string"
# console.log(simpleString)
# console.log(getSegments(simpleString))
#
# complexString = "a string; is like this; it's great"
# console.log(complexString)
# console.log(getSegments(complexString))
#
# veryComplexString = "something (with;nested);[(expres;sio;ns)];end;([([([(([;;;]))])])]) segment"
# console.log(veryComplexString)
# console.log(getSegments(veryComplexString))
