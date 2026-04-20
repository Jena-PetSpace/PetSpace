package io.seunghwanly.kakao_maps_flutter.constant

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import com.kakao.vectormap.label.LabelStyle
import com.kakao.vectormap.label.LabelTextStyle

class DefaultLabelTextStyle {
    companion object {
        const val FONT_SIZE: Int = 14
        const val FONT_COLOR: Int = 0xFF000000.toInt()
        const val STROKE_THICKNESS: Int = 4
        const val STROKE_COLOR: Int = 0xFFFFFFFF.toInt()

        fun getTextStyle(): LabelTextStyle {
            return LabelTextStyle.from(
                FONT_SIZE,
                FONT_COLOR,
                STROKE_THICKNESS,
                STROKE_COLOR,
            )
        }
    }
}

class DefaultLabelStyle {
    companion object {
        fun createPinBitmap(color: Int = 0xFF1E3A5F.toInt(), sizeInPx: Int = 48): Bitmap {
            val bitmap = Bitmap.createBitmap(sizeInPx, sizeInPx, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            val paint = Paint(Paint.ANTI_ALIAS_FLAG)
            paint.color = color
            val radius = sizeInPx / 2f
            canvas.drawCircle(radius, radius, radius * 0.85f, paint)
            val stroke = Paint(Paint.ANTI_ALIAS_FLAG)
            stroke.color = 0xFFFFFFFF.toInt()
            stroke.style = Paint.Style.STROKE
            stroke.strokeWidth = sizeInPx * 0.08f
            canvas.drawCircle(radius, radius, radius * 0.85f, stroke)
            return bitmap
        }

        fun getStyle(): LabelStyle {
            return LabelStyle.from(createPinBitmap())
                .setTextStyles(DefaultLabelTextStyle.getTextStyle())
        }
    }
}