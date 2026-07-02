#!/usr/bin/env python3
"""
Icarus Compute Pipeline Builder - Launches Vulkan compute shaders on
unified memory buffers with minimal boilerplate.
"""

import vulkan as vk
from icarus_vulkan_engine import IcarusVulkanBackend, UMATensor
import numpy as np
from typing import List, Tuple

class IcarusComputePipeline:
    def __init__(self, backend: IcarusVulkanBackend, shader_path: str, push_constant_size: int = 0):
        self.backend = backend
        self.device = backend.device
        self.queue = backend.queue
        self.command_pool = backend.command_pool

        # Load SPIR-V binary
        with open(shader_path, 'rb') as f:
            spirv = f.read()

        # Create shader module
        module_info = vk.VkShaderModuleCreateInfo(codeSize=len(spirv), pCode=spirv)
        self.shader_module = vk.vkCreateShaderModule(self.device, module_info, None)

        # Descriptor set layout (generic: we'll define set=0 with bindings 0..N)
        # We'll build it dynamically based on the number of buffers passed.
        # For simplicity, we assume the shader uses consecutive storage buffers starting at binding 0.
        # A full implementation would parse SPIR-V reflection; here we require manual count.

        # Pipeline layout with push constants if needed
        push_range = vk.VkPushConstantRange(
            stageFlags=vk.VK_SHADER_STAGE_COMPUTE_BIT,
            offset=0,
            size=push_constant_size
        ) if push_constant_size else None
        layout_info = vk.VkPipelineLayoutCreateInfo(
            setLayoutCount=0,  # We'll update this after descriptor set layout is created
            pSetLayouts=None,
            pushConstantRangeCount=1 if push_constant_size else 0,
            pPushConstantRanges=[push_range] if push_constant_size else None
        )
        self.pipeline_layout = vk.vkCreatePipelineLayout(self.device, layout_info, None)

        # Create compute pipeline
        pipeline_info = vk.VkComputePipelineCreateInfo(
            stage=vk.VkPipelineShaderStageCreateInfo(
                stage=vk.VK_SHADER_STAGE_COMPUTE_BIT,
                module=self.shader_module,
                pName="main"
            ),
            layout=self.pipeline_layout,
        )
        self.pipeline = vk.vkCreateComputePipelines(self.device, None, [pipeline_info])[0]

    def create_descriptor_set(self, buffers: List[UMATensor]):
        """Create a descriptor set that binds the list of UMATensors as storage buffers."""
        # Build descriptor set layout bindings dynamically
        bindings = []
        for i, tensor in enumerate(buffers):
            bindings.append(vk.VkDescriptorSetLayoutBinding(
                binding=i,
                descriptorType=vk.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
                descriptorCount=1,
                stageFlags=vk.VK_SHADER_STAGE_COMPUTE_BIT,
            ))
        layout_info = vk.VkDescriptorSetLayoutCreateInfo(bindings=bindings)
        descriptor_set_layout = vk.vkCreateDescriptorSetLayout(self.device, layout_info, None)

        # Update pipeline layout to include this set layout
        # (Note: ideally layout is created before pipeline, but we can reconstruct)
        # This is a simplified version; a robust implementation would pre-parse shader reflection.
        layout_info2 = vk.VkPipelineLayoutCreateInfo(
            setLayoutCount=1,
            pSetLayouts=[descriptor_set_layout],
            pushConstantRangeCount=1 if self.pipeline_layout else 0,
            pPushConstantRanges=None  # we can reuse from earlier
        )
        self.pipeline_layout = vk.vkCreatePipelineLayout(self.device, layout_info2, None)

        # Allocate descriptor set from pool
        pool_sizes = [vk.VkDescriptorPoolSize(
            type=vk.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
            descriptorCount=len(buffers)
        )]
        pool_info = vk.VkDescriptorPoolCreateInfo(
            maxSets=1,
            poolSizes=pool_sizes
        )
        descriptor_pool = vk.vkCreateDescriptorPool(self.device, pool_info, None)
        alloc_info = vk.VkDescriptorSetAllocateInfo(
            descriptorPool=descriptor_pool,
            setLayouts=[descriptor_set_layout]
        )
        descriptor_set = vk.vkAllocateDescriptorSets(self.device, alloc_info)[0]

        # Write buffer descriptors
        writes = []
        buffer_infos = []
        for i, tensor in enumerate(buffers):
            buffer_info = vk.VkDescriptorBufferInfo(
                buffer=tensor.buffer,
                offset=0,
                range=tensor.nbytes
            )
            buffer_infos.append(buffer_info)
            writes.append(vk.VkWriteDescriptorSet(
                dstSet=descriptor_set,
                dstBinding=i,
                dstArrayElement=0,
                descriptorCount=1,
                descriptorType=vk.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
                pBufferInfo=[buffer_info],
            ))
        vk.vkUpdateDescriptorSets(self.device, writes, [])

        self.descriptor_set = descriptor_set
        self.descriptor_pool = descriptor_pool
        self.descriptor_set_layout = descriptor_set_layout

    def dispatch(self, global_size: Tuple[int, int, int], push_constants: bytes = None):
        """Record and submit a compute dispatch."""
        # Create command buffer
        alloc_info = vk.VkCommandBufferAllocateInfo(
            commandPool=self.command_pool,
            level=vk.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
            commandBufferCount=1
        )
        cmd_buf = vk.vkAllocateCommandBuffers(self.device, alloc_info)[0]

        begin_info = vk.VkCommandBufferBeginInfo(flags=vk.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT)
        vk.vkBeginCommandBuffer(cmd_buf, begin_info)
        vk.vkCmdBindPipeline(cmd_buf, vk.VK_PIPELINE_BIND_POINT_COMPUTE, self.pipeline)
        vk.vkCmdBindDescriptorSets(cmd_buf, vk.VK_PIPELINE_BIND_POINT_COMPUTE,
                                    self.pipeline_layout, 0, [self.descriptor_set], [])
        if push_constants:
            vk.vkCmdPushConstants(cmd_buf, self.pipeline_layout,
                                  vk.VK_SHADER_STAGE_COMPUTE_BIT, 0, len(push_constants), push_constants)
        vk.vkCmdDispatch(cmd_buf, *global_size)
        vk.vkEndCommandBuffer(cmd_buf)

        # Submit
        submit_info = vk.VkSubmitInfo(commandBuffers=[cmd_buf])
        vk.vkQueueSubmit(self.queue, [submit_info], None)
        vk.vkQueueWaitIdle(self.queue)

        vk.vkFreeCommandBuffers(self.device, self.command_pool, [cmd_buf])

    def cleanup(self):
        vk.vkDestroyPipeline(self.device, self.pipeline, None)
        vk.vkDestroyPipelineLayout(self.device, self.pipeline_layout, None)
        vk.vkDestroyShaderModule(self.device, self.shader_module, None)
        if hasattr(self, 'descriptor_pool'):
            vk.vkDestroyDescriptorPool(self.device, self.descriptor_pool, None)
        if hasattr(self, 'descriptor_set_layout'):
            vk.vkDestroyDescriptorSetLayout(self.device, self.descriptor_set_layout, None)