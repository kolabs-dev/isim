#pragma once
/* isim AudioToolbox for C: Audio Processing Graph Services (Apple's AUGraph.h, deprecated but usable), over isim's
 * Swift AUGraph (swift/overlays/AudioToolbox/AudioUnits.swift). */
#include <AudioToolbox/AUComponent.h>
#if !defined(__swift__)
__BEGIN_DECLS
#pragma clang assume_nonnull begin
enum {
    kAUGraphErr_NodeNotFound = -10860,
    kAUGraphErr_InvalidConnection = -10861,
    kAUGraphErr_OutputNodeErr = -10862,
    kAUGraphErr_CannotDoInCurrentContext = -10863,
    kAUGraphErr_InvalidAudioUnit = -10864,
};
AT_EXPORT OSStatus NewAUGraph(AUGraph _Nullable *_Nonnull outGraph);
AT_EXPORT OSStatus DisposeAUGraph(AUGraph inGraph);
AT_EXPORT OSStatus AUGraphAddNode(AUGraph inGraph, const AudioComponentDescription *inDescription, AUNode *outNode);
AT_EXPORT OSStatus AUGraphRemoveNode(AUGraph inGraph, AUNode inNode);
AT_EXPORT OSStatus AUGraphGetNodeCount(AUGraph inGraph, UInt32 *outNumberOfNodes);
AT_EXPORT OSStatus AUGraphGetIndNode(AUGraph inGraph, UInt32 inIndex, AUNode *outNode);
AT_EXPORT OSStatus AUGraphNodeInfo(AUGraph inGraph, AUNode inNode, AudioComponentDescription *_Nullable outDescription,
                                   AudioUnit _Nullable *_Nullable outAudioUnit);
AT_EXPORT OSStatus AUGraphConnectNodeInput(AUGraph inGraph, AUNode inSourceNode, UInt32 inSourceOutputNumber, AUNode inDestNode,
                                           UInt32 inDestInputNumber);
AT_EXPORT OSStatus AUGraphSetNodeInputCallback(AUGraph inGraph, AUNode inDestNode, UInt32 inDestInputNumber,
                                               const AURenderCallbackStruct *inInputCallback);
AT_EXPORT OSStatus AUGraphDisconnectNodeInput(AUGraph inGraph, AUNode inDestNode, UInt32 inDestInputNumber);
AT_EXPORT OSStatus AUGraphClearConnections(AUGraph inGraph);
AT_EXPORT OSStatus AUGraphUpdate(AUGraph inGraph, Boolean *_Nullable outIsUpdated);
AT_EXPORT OSStatus AUGraphOpen(AUGraph inGraph);
AT_EXPORT OSStatus AUGraphClose(AUGraph inGraph);
AT_EXPORT OSStatus AUGraphInitialize(AUGraph inGraph);
AT_EXPORT OSStatus AUGraphUninitialize(AUGraph inGraph);
AT_EXPORT OSStatus AUGraphStart(AUGraph inGraph);
AT_EXPORT OSStatus AUGraphStop(AUGraph inGraph);
AT_EXPORT OSStatus AUGraphIsOpen(AUGraph inGraph, Boolean *outIsOpen);
AT_EXPORT OSStatus AUGraphIsInitialized(AUGraph inGraph, Boolean *outIsInitialized);
AT_EXPORT OSStatus AUGraphIsRunning(AUGraph inGraph, Boolean *outIsRunning);
AT_EXPORT OSStatus AUGraphGetCPULoad(AUGraph inGraph, Float32 *outAverageCPULoad);
AT_EXPORT OSStatus AUGraphGetMaxCPULoad(AUGraph inGraph, Float32 *outMaxLoad);
AT_EXPORT OSStatus AUGraphAddRenderNotify(AUGraph inGraph, AURenderCallback inCallback, void *_Nullable inRefCon);
AT_EXPORT OSStatus AUGraphRemoveRenderNotify(AUGraph inGraph, AURenderCallback inCallback, void *_Nullable inRefCon);
#pragma clang assume_nonnull end
__END_DECLS
#endif
