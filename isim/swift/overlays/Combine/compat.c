// Binary compatibility for apps built before Subscribers.Completion became @frozen (as in Apple's Combine):
// resilient clients look up enum case tags through these symbols. Payload cases are numbered first.
__attribute__((used, visibility("default"))) const int $s7Combine11SubscribersO10CompletionO7failureyAEy_xGxcAGms5ErrorRzlFWC __asm__("_$s7Combine11SubscribersO10CompletionO7failureyAEy_xGxcAGms5ErrorRzlFWC") = 0;
__attribute__((used, visibility("default"))) const int $s7Combine11SubscribersO10CompletionO8finishedyAEy_xGAGms5ErrorRzlFWC __asm__("_$s7Combine11SubscribersO10CompletionO8finishedyAEy_xGAGms5ErrorRzlFWC") = 1;
