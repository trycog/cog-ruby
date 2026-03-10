# frozen_string_literal: true

module CogRuby
  module Protobuf
    # Wire types
    WIRE_VARINT    = 0
    WIRE_DELIMITED = 2

    module_function

    # --- Low-level encoding ---

    def encode_varint(value)
      value &= 0xFFFFFFFFFFFFFFFF if value < 0
      buf = []
      loop do
        byte = value & 0x7F
        value >>= 7
        if value == 0
          buf << byte
          break
        else
          buf << (byte | 0x80)
        end
      end
      buf.pack('C*')
    end

    def encode_tag(field_number, wire_type)
      encode_varint((field_number << 3) | wire_type)
    end

    # --- Field encoders ---

    def encode_string_field(field_number, value)
      return ''.b if value.nil? || value.empty?

      data = value.b
      encode_tag(field_number, WIRE_DELIMITED) + encode_varint(data.bytesize) + data
    end

    def encode_int32_field(field_number, value)
      return ''.b if value == 0

      encode_tag(field_number, WIRE_VARINT) + encode_varint(value)
    end

    def encode_bool_field(field_number, value)
      return ''.b unless value

      encode_tag(field_number, WIRE_VARINT) + encode_varint(1)
    end

    def encode_message_field(field_number, message_data)
      data = message_data.b
      return ''.b if data.empty?

      encode_tag(field_number, WIRE_DELIMITED) + encode_varint(data.bytesize) + data
    end

    def encode_packed_int32_field(field_number, values)
      return ''.b if values.empty?

      packed = values.map { |v| encode_varint(v) }.join.b
      encode_tag(field_number, WIRE_DELIMITED) + encode_varint(packed.bytesize) + packed
    end

    def encode_repeated_message_field(field_number, messages)
      return ''.b if messages.empty?

      messages.map do |msg_data|
        data = msg_data.b
        encode_tag(field_number, WIRE_DELIMITED) + encode_varint(data.bytesize) + data
      end.join.b
    end

    def encode_repeated_string_field(field_number, strings)
      return ''.b if strings.empty?

      strings.map do |s|
        data = s.b
        encode_tag(field_number, WIRE_DELIMITED) + encode_varint(data.bytesize) + data
      end.join.b
    end

    # --- SCIP message encoders ---

    def encode_index(index)
      parts = []
      parts << encode_message_field(1, encode_metadata(index.metadata))
      parts << encode_repeated_message_field(2, index.documents.map { |d| encode_document(d) })
      parts << encode_repeated_message_field(3, index.external_symbols.map { |s| encode_symbol_information(s) })
      parts.join.b
    end

    def encode_metadata(m)
      return ''.b if m.nil?

      parts = []
      parts << encode_int32_field(1, m.version)
      parts << encode_message_field(2, encode_tool_info(m.tool_info))
      parts << encode_string_field(3, m.project_root)
      parts << encode_int32_field(4, m.text_document_encoding)
      parts.join.b
    end

    def encode_tool_info(t)
      return ''.b if t.nil?

      parts = []
      parts << encode_string_field(1, t.name)
      parts << encode_string_field(2, t.version)
      parts << encode_repeated_string_field(3, t.arguments)
      parts.join.b
    end

    def encode_document(d)
      parts = []
      parts << encode_string_field(1, d.relative_path)
      parts << encode_repeated_message_field(2, d.occurrences.map { |o| encode_occurrence(o) })
      parts << encode_repeated_message_field(3, d.symbols.map { |s| encode_symbol_information(s) })
      parts << encode_string_field(4, d.language)
      parts.join.b
    end

    def encode_occurrence(o)
      parts = []
      parts << encode_packed_int32_field(1, o.range)
      parts << encode_string_field(2, o.symbol)
      parts << encode_int32_field(3, o.symbol_roles)
      parts << encode_int32_field(5, o.syntax_kind)
      parts << encode_packed_int32_field(7, o.enclosing_range)
      parts.join.b
    end

    def encode_symbol_information(s)
      parts = []
      parts << encode_string_field(1, s.symbol)
      parts << encode_repeated_string_field(3, s.documentation)
      parts << encode_repeated_message_field(4, s.relationships.map { |r| encode_relationship(r) })
      parts << encode_int32_field(5, s.kind)
      parts << encode_string_field(6, s.display_name)
      parts << encode_string_field(8, s.enclosing_symbol)
      parts.join.b
    end

    def encode_relationship(r)
      parts = []
      parts << encode_string_field(1, r.symbol)
      parts << encode_bool_field(2, r.is_reference)
      parts << encode_bool_field(3, r.is_implementation)
      parts << encode_bool_field(4, r.is_type_definition)
      parts << encode_bool_field(5, r.is_definition)
      parts << encode_string_field(6, r.kind)
      parts.join.b
    end
  end
end
