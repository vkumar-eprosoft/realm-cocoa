////////////////////////////////////////////////////////////////////////////
//
// Copyright 2016 Realm Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
////////////////////////////////////////////////////////////////////////////

#import "RLMObjectInfo.hpp"

#import "RLMRealm_Private.hpp"
#import "RLMObjectSchema.h"
#import "RLMSchema.h"
#import "RLMProperty_Private.h"
#import "RLMQueryUtil.hpp"
#import "RLMUtil.hpp"

#import "object_schema.hpp"
#import "object_store.hpp"
#import "schema.hpp"

#import <realm/table.hpp>

using namespace realm;

RLMObjectInfo::RLMObjectInfo(RLMRealm *realm, RLMObjectSchema *rlmObjectSchema,
                             const realm::ObjectSchema *objectSchema)
: realm(realm), rlmObjectSchema(rlmObjectSchema), objectSchema(objectSchema) { }

realm::Table *RLMObjectInfo::table() const {
    if (!m_table) {
        m_table = ObjectStore::table_for_object_type(realm.group, objectSchema->name).get();
    }
    return m_table;
}

RLMProperty *RLMObjectInfo::propertyForTableColumn(NSUInteger col) const noexcept {
    // FIXME: optimize
    auto const& props = objectSchema->persisted_properties;
    for (size_t i = 0; i < props.size(); ++i) {
        if (props[i].table_column == col) {
            return rlmObjectSchema.properties[i];
        }
    }
    return nil;
}

NSUInteger RLMObjectInfo::tableColumn(NSString *propertyName) const {
    return tableColumn(RLMValidatedProperty(rlmObjectSchema, propertyName));
}

NSUInteger RLMObjectInfo::tableColumn(RLMProperty *property) const {
    return objectSchema->persisted_properties[property.index].table_column;
}

RLMObjectInfo &RLMObjectInfo::linkTargetType(size_t index) {
    if (index < m_linkTargets.size() && m_linkTargets[index]) {
        return *m_linkTargets[index];
    }
    if (m_linkTargets.size() <= index) {
        m_linkTargets.resize(index + 1);
    }
    m_linkTargets[index] = &realm->_info[rlmObjectSchema.properties[index].objectClassName];
    return *m_linkTargets[index];
}

RLMSchemaInfo::impl::iterator RLMSchemaInfo::begin() noexcept { return m_objects.begin(); }
RLMSchemaInfo::impl::iterator RLMSchemaInfo::end() noexcept { return m_objects.end(); }
RLMSchemaInfo::impl::const_iterator RLMSchemaInfo::begin() const noexcept { return m_objects.begin(); }
RLMSchemaInfo::impl::const_iterator RLMSchemaInfo::end() const noexcept { return m_objects.end(); }

RLMObjectInfo& RLMSchemaInfo::operator[](NSString *name) {
    auto it = m_objects.find(name);
    if (it == m_objects.end()) {
        @throw RLMException(@"Object type '%@' is not managed by the Realm. "
                            @"If using a custom `objectClasses` / `objectTypes` array in your configuration, "
                            @"add `%@` to the list of `objectClasses` / `objectTypes`.",
                            name, name);
    }
    return *&it->second;
}

void RLMSchemaInfo::init(RLMRealm *realm, RLMSchema *rlmSchema, realm::Schema const& schema) {
    REALM_ASSERT(rlmSchema.objectSchema.count == schema.size());
    REALM_ASSERT(m_objects.empty());

    m_objects.reserve(schema.size());
    for (RLMObjectSchema *rlmObjectSchema in rlmSchema.objectSchema) {
        m_objects.emplace(std::piecewise_construct,
                          std::forward_as_tuple(rlmObjectSchema.className),
                          std::forward_as_tuple(realm, rlmObjectSchema,
                                                &*schema.find(rlmObjectSchema.className.UTF8String)));
    }
}
