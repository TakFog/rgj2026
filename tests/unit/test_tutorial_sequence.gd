extends TestCase


func test_starts_on_the_first_caption() -> void:
	var sequence := TutorialSequence.new()
	assert_eq(sequence.index, 0)
	assert_eq(sequence.caption(), TutorialSequence.CAPTIONS[0])


func test_advances_and_wraps() -> void:
	var sequence := TutorialSequence.new()
	sequence.advance()
	assert_eq(sequence.index, 1)
	sequence.advance()
	assert_eq(sequence.index, 2)
	sequence.advance()
	assert_eq(sequence.index, 0, "wraps after the last step")


func test_reset_returns_to_the_first_caption() -> void:
	var sequence := TutorialSequence.new()
	sequence.advance()
	sequence.reset()
	assert_eq(sequence.index, 0)


func test_every_caption_is_present() -> void:
	var sequence := TutorialSequence.new()
	assert_eq(sequence.count(), 3)
	for i in sequence.count():
		assert_false(sequence.caption().is_empty(), "caption %d is empty" % i)
		sequence.advance()
